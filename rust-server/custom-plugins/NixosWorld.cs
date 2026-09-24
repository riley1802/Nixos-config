using System;
using System.Collections.Generic;
using System.Globalization;
using Oxide.Core;
using UnityEngine;

namespace Oxide.Plugins
{
    [Info("NixosWorld", "NixOS", "1.0.0")]
    [Description("World clock, weather, population, NPC health, and vehicle lifecycle rules.")]
    public class NixosWorld : RustPlugin
    {
        private const float DayDurationSeconds = 3600f;
        private const float NightDurationSeconds = 600f;
        private const long VehicleExpirySeconds = 14L * 24L * 60L * 60L;

        private StoredData storedData;
        private readonly HashSet<BaseNetworkable> replicatedNpcs = new HashSet<BaseNetworkable>();
        private readonly Dictionary<EntityFuelSystem, float> pendingFuelUse =
            new Dictionary<EntityFuelSystem, float>();

        private class StoredData
        {
            public Dictionary<ulong, VehicleRecord> Vehicles = new Dictionary<ulong, VehicleRecord>();
        }

        private class VehicleRecord
        {
            public ulong OwnerId;
            public long LastUsedUtc;
        }

        private void Init()
        {
            try
            {
                storedData = Interface.Oxide.DataFileSystem.ReadObject<StoredData>(Name);
            }
            catch
            {
                storedData = new StoredData();
            }
            if (storedData == null)
                storedData = new StoredData();
        }

        private void OnServerInitialized()
        {
            SetConvar("env.progresstime", "false");
            SetConvar("server.planttickscale", "10");
            SetConvar("decay.scale", "0.2");

            SetConvar("bear.population", "10");
            SetConvar("boar.population", "25");
            SetConvar("chicken.population", "15");
            SetConvar("stag.population", "15");
            SetConvar("wolf2.population", "10");

            SetConvar("modularcar.population", "6");
            SetConvar("minicopter.population", "5");
            SetConvar("scraptransporthelicopter.population", "2");
            SetConvar("motorrowboat.population", "2");
            SetConvar("traincar.population", "4");
            SetConvar("hackablelockedcrate.requiredhackseconds", "300");
            SetConvar("bradley.respawndelayminutes", "30");
            SetEventDelay("cargo", 9d, 15.6d);
            SetEventDelay("chinook", 13.5d, 27d);
            SetEventDelay("patrol_heli", 18d, 27d);

            DisableVehicleDecay();
            ApplyWeather();
            timer.Every(1f, AdvanceClock);
            timer.Every(10f * 60f, ApplyWeather);
            timer.Every(60f * 60f, RemoveExpiredVehicles);
            Puts("NixOS world rules initialized.");
        }

        private void Unload()
        {
            SetConvar("env.progresstime", "true");
            SaveData();
        }

        private void OnServerSave() => SaveData();

        private void SetConvar(string name, string value)
        {
            ConsoleSystem.Run(ConsoleSystem.Option.Server, name, value);
        }

        private void SetEventDelay(string eventName, double minimumHours, double maximumHours)
        {
            ConsoleSystem.Run(
                ConsoleSystem.Option.Server,
                "events.set_event_min_delay",
                eventName,
                minimumHours.ToString(CultureInfo.InvariantCulture));
            ConsoleSystem.Run(
                ConsoleSystem.Option.Server,
                "events.set_event_max_delay",
                eventName,
                maximumHours.ToString(CultureInfo.InvariantCulture));
        }

        private void AdvanceClock()
        {
            if (TOD_Sky.Instance == null)
                return;

            float hour = TOD_Sky.Instance.Cycle.Hour;
            bool daytime = hour >= 6f && hour < 18f;
            float gameHoursPerSecond = 12f / (daytime ? DayDurationSeconds : NightDurationSeconds);
            TOD_Sky.Instance.Cycle.Hour = (hour + gameHoursPerSecond) % 24f;
        }

        private void ApplyWeather()
        {
            float severity = UnityEngine.Random.Range(0.45f, 1f);
            SetConvar("weather.cloud_opacity", severity.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture));
            SetConvar("weather.cloud_coverage", severity.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture));
            SetConvar("weather.wind", UnityEngine.Random.Range(0.35f, 1f).ToString("0.00", System.Globalization.CultureInfo.InvariantCulture));
            SetConvar("weather.rain", UnityEngine.Random.Range(0.25f, severity).ToString("0.00", System.Globalization.CultureInfo.InvariantCulture));
            SetConvar("weather.fog", UnityEngine.Random.Range(0.1f, 0.65f).ToString("0.00", System.Globalization.CultureInfo.InvariantCulture));
        }

        private void DisableVehicleDecay()
        {
            string effectivelyDisabled = "2147483647";
            SetConvar("playerhelicopter.outsidedecayminutes", effectivelyDisabled);
            SetConvar("playerhelicopter.insidedecayminutes", effectivelyDisabled);
            SetConvar("modularcar.outsidedecayminutes", effectivelyDisabled);
            SetConvar("motorrowboat.outsidedecayminutes", effectivelyDisabled);
            SetConvar("motorrowboat.deepwaterdecayminutes", effectivelyDisabled);
        }

        private void OnEntitySpawned(BaseNetworkable entity)
        {
            if (entity == null || replicatedNpcs.Contains(entity))
                return;

            ScientistNPC scientist = entity as ScientistNPC;
            if (scientist != null)
            {
                NextTick(() =>
                {
                    if (scientist == null || scientist.IsDestroyed)
                        return;
                    scientist.SetMaxHealth(scientist.MaxHealth() * 2f);
                    scientist.health = scientist.MaxHealth();
                    ReplicateScientist(scientist, 2);
                });
                return;
            }

            BradleyAPC bradley = entity as BradleyAPC;
            if (bradley != null)
            {
                NextTick(() => DoubleHealth(bradley));
                return;
            }

            PatrolHelicopter helicopter = entity as PatrolHelicopter;
            if (helicopter != null)
                NextTick(() => DoubleHealth(helicopter));
        }

        private void DoubleHealth(BaseCombatEntity entity)
        {
            if (entity == null || entity.IsDestroyed)
                return;
            entity.SetMaxHealth(entity.MaxHealth() * 2f);
            entity.health = entity.MaxHealth();
        }

        private void ReplicateScientist(ScientistNPC original, int count)
        {
            for (int index = 0; index < count; index++)
            {
                Vector2 offset = UnityEngine.Random.insideUnitCircle * 3f;
                Vector3 position = original.transform.position + new Vector3(offset.x, 0f, offset.y);
                BaseNetworkable copy = GameManager.server.CreateEntity(
                    original.PrefabName,
                    position,
                    original.transform.rotation);
                if (copy == null)
                    continue;

                replicatedNpcs.Add(copy);
                copy.Spawn();
                NextTick(() => replicatedNpcs.Remove(copy));

                BaseCombatEntity combatCopy = copy as BaseCombatEntity;
                if (combatCopy != null)
                {
                    combatCopy.SetMaxHealth(original.MaxHealth());
                    combatCopy.health = combatCopy.MaxHealth();
                }
            }
        }

        private void OnEntityMounted(BaseMountable mountable, BasePlayer player)
        {
            if (mountable == null || player == null)
                return;

            BaseVehicle vehicle = mountable.GetComponentInParent<BaseVehicle>();
            if (vehicle == null || vehicle.net == null)
                return;

            ulong networkId = vehicle.net.ID.Value;
            VehicleRecord record;
            if (!storedData.Vehicles.TryGetValue(networkId, out record))
            {
                record = new VehicleRecord
                {
                    OwnerId = player.userID
                };
                storedData.Vehicles[networkId] = record;
                if (vehicle.OwnerID == 0)
                    vehicle.OwnerID = player.userID;
            }

            record.LastUsedUtc = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            SaveData();
        }

        private void OnNewSave(string filename)
        {
            if (storedData == null)
                return;

            storedData.Vehicles.Clear();
            SaveData();
        }

        private void OnEntityKill(BaseNetworkable entity)
        {
            if (storedData == null || !(entity is BaseVehicle) || entity.net == null)
                return;

            if (storedData.Vehicles.Remove(entity.net.ID.Value))
                SaveData();
        }

        private object CanUseFuel(
            EntityFuelSystem fuelSystem,
            StorageContainer fuelContainer,
            float seconds,
            float fuelUsedPerSecond)
        {
            if (fuelSystem == null)
                return null;

            Item fuel = fuelContainer?.inventory?.FindItemByItemName("lowgradefuel");
            if (fuel == null)
                return null;

            float remainder;
            pendingFuelUse.TryGetValue(fuelSystem, out remainder);
            remainder += seconds * fuelUsedPerSecond * 0.5f;
            int unitsToUse = Mathf.FloorToInt(remainder);
            pendingFuelUse[fuelSystem] = remainder - unitsToUse;
            if (unitsToUse > 0)
                fuel.UseItem(Math.Min(unitsToUse, fuel.amount));
            return unitsToUse;
        }

        private void RemoveExpiredVehicles()
        {
            long now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            List<ulong> removeRecords = new List<ulong>();
            List<BaseVehicle> removeVehicles = new List<BaseVehicle>();
            foreach (KeyValuePair<ulong, VehicleRecord> entry in storedData.Vehicles)
            {
                if (now - entry.Value.LastUsedUtc < VehicleExpirySeconds)
                    continue;

                BaseNetworkable networkable = BaseNetworkable.serverEntities.Find(new NetworkableId(entry.Key));
                BaseVehicle vehicle = networkable as BaseVehicle;
                if (vehicle != null && !vehicle.IsDestroyed)
                    removeVehicles.Add(vehicle);
                removeRecords.Add(entry.Key);
            }

            foreach (ulong networkId in removeRecords)
                storedData.Vehicles.Remove(networkId);
            if (removeRecords.Count > 0)
                SaveData();
            foreach (BaseVehicle vehicle in removeVehicles)
                vehicle.Kill();
        }

        private void SaveData()
        {
            Interface.Oxide.DataFileSystem.WriteObject(Name, storedData);
        }
    }
}
