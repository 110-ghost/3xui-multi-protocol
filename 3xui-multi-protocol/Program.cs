using Newtonsoft.Json;

while (true)
{
    try
    {
        using var db = new MultiProtocolContext();

        // 1. Load initial data
        var currentTraffics = db.Client_Traffics.ToList();
        if (!File.Exists("LocalDB.json"))
        {
            var initialLocalDb = new LocalDB { Sec = 10, clients = currentTraffics };
            File.WriteAllText("LocalDB.json", JsonConvert.SerializeObject(initialLocalDb));
        }
        
        var localDbJson = File.ReadAllText("LocalDB.json");
        var localDB = JsonConvert.DeserializeObject<LocalDB>(localDbJson);

        if (localDB?.clients == null)
        {
            Console.WriteLine("LocalDB.json is corrupted or empty. Skipping this cycle.");
            Thread.Sleep(25 * 1000);
            continue;
        }

        // 2. Extract all clients from all inbounds
        List<Client> allClients = [];
        var inbounds = db.Inbounds.ToList();
        foreach (var inbound in inbounds)
        {
            if (!string.IsNullOrEmpty(inbound.Settings))
            {
                var setting = JsonConvert.DeserializeObject<InboundSetting>(inbound.Settings);
                if (setting?.clients != null)
                {
                    allClients.AddRange(setting.clients);
                }
            }
        }

        // 3. Process clients with the same subId
        List<Client> finalClients = [];
        List<Client_Traffics> finalTraffics = [];

        var groupedBySubId = allClients
            .Where(c => c != null && !string.IsNullOrEmpty(c.subId)) 
            .GroupBy(c => c.subId)
            .Where(g => g.Count() > 1);

        foreach (var group in groupedBySubId)
        {
            var clientsInGroup = group.ToList();
            var trafficInGroup = clientsInGroup
                .Select(c => currentTraffics.FirstOrDefault(t => t.Email == c!.email)) // Added '!'
                .Where(t => t != null)
                .ToList();

            if (trafficInGroup.Count == 0) continue;

            // Calculate unified values with '!' to suppress warnings
            long? maxTotalGB = clientsInGroup.Max(c => c!.totalGB);
            long? maxUP = trafficInGroup.Max(t => t!.Up);
            long? maxDOWN = trafficInGroup.Max(t => t!.Down);
            long? maxExpiry = trafficInGroup.Max(t => t!.Expiry_Time);
            long? minExpiry = trafficInGroup.Min(t => t!.Expiry_Time);
            long? expiryTime = maxExpiry > 0 ? maxExpiry : minExpiry;

            long? cumulativeUp = 0;
            long? cumulativeDown = 0;

            foreach (var traffic in trafficInGroup)
            {
                var oldTraffic = localDB.clients.FirstOrDefault(c => c.Email == traffic!.Email); // Added '!'
                if (oldTraffic == null) continue;

                if (traffic!.Up > oldTraffic.Up) // Added '!'
                {
                    cumulativeUp += traffic.Up - oldTraffic.Up;
                }
                if (traffic.Down > oldTraffic.Down)
                {
                    cumulativeDown += traffic.Down - oldTraffic.Down;
                }
            }
            
            foreach (var traffic in trafficInGroup)
            {
                traffic!.Up = (maxUP ?? 0) + cumulativeUp; // Added '!'
                traffic.Down = (maxDOWN ?? 0) + cumulativeDown;
                traffic.Total = trafficInGroup.Max(t => t!.Total);
                traffic.Expiry_Time = expiryTime;
                finalTraffics.Add(traffic);
            }

            foreach (var client in clientsInGroup)
            {
                client!.totalGB = maxTotalGB; // Added '!'
                client.expiryTime = expiryTime;
                finalClients.Add(client);
            }
        }

        // 4. Update the database
        if (finalTraffics.Any())
        {
            db.Client_Traffics.UpdateRange(finalTraffics);
        }

        List<Inbound> finalInbounds = [];
        var inboundsToUpdate = db.Inbounds
            .Where(i => i.Protocol == "vmess" || i.Protocol == "vless")
            .ToList();

        foreach (var inbound in inboundsToUpdate)
        {
            if (string.IsNullOrEmpty(inbound.Settings)) continue;
            
            var setting = JsonConvert.DeserializeObject<InboundSetting>(inbound.Settings);
            if (setting?.clients == null) continue;

            var finalClientsDict = finalClients
                .Where(fc => fc!.email != null && currentTraffics.Any(ct => ct.Email == fc.email && ct.Inbound_Id == inbound.Id)) // Added '!'
                .ToDictionary(fc => fc.email!); 

            if (finalClientsDict.Any())
            {
                setting.clients.RemoveAll(c => c.email != null && finalClientsDict.ContainsKey(c.email));
                setting.clients.AddRange(finalClientsDict.Values);
                
                inbound.Settings = JsonConvert.SerializeObject(setting, new JsonSerializerSettings { NullValueHandling = NullValueHandling.Ignore });
                finalInbounds.Add(inbound);
            }
        }
        
        if (finalInbounds.Any())
        {
            db.Inbounds.UpdateRange(finalInbounds);
        }
        
        db.SaveChanges();

        // 5. Update local file for the next run
        var updatedTraffics = new MultiProtocolContext().Client_Traffics.ToList();
        var updateLocal = new LocalDB { Sec = localDB.Sec, clients = updatedTraffics };
        File.WriteAllText("LocalDB.json", JsonConvert.SerializeObject(updateLocal));

        Console.WriteLine("Done");
    }
    catch (Exception e)
    {
        Console.WriteLine($"An error occurred: {e.Message}");
    }

    Thread.Sleep(25 * 1000);
}