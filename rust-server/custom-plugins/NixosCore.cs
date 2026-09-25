using System;
using System.Collections.Generic;
using System.Globalization;
using System.Reflection;
using Newtonsoft.Json;
using Oxide.Core;
using Oxide.Core.Plugins;
using UnityEngine;

namespace Oxide.Plugins
{
    [Info("NixosCore", "NixOS", "1.0.2")]
    [Description("LAN administration, PvE rules, homes, respawn loadout, and player quality of life.")]
    public class NixosCore : RustPlugin
    {
        [PluginReference] private Plugin Backpacks;
        [PluginReference] private Plugin RemoverTool;

        private const int MaximumHomes = 3;
        private const float PlayerMaximumHealth = 200f;
        private const string BackpackPermission = "backpacks.use";
        private const string RemoverPermission = "removertool.normal";

        private StoredData storedData;
        private readonly Dictionary<ulong, float> lastHealth = new Dictionary<ulong, float>();
        private readonly Dictionary<ulong, float> lastStructureAlert = new Dictionary<ulong, float>();
        private readonly FieldInfo sleepingBagUnlockTime =
            typeof(SleepingBag).GetField("unlockTime", BindingFlags.NonPublic | BindingFlags.Instance);

        private class StoredData
        {
            public Dictionary<ulong, Dictionary<string, SerializableVector3>> Homes =
                new Dictionary<ulong, Dictionary<string, SerializableVector3>>();
            public Dictionary<ulong, SerializableVector3> LatestDeaths =
                new Dictionary<ulong, SerializableVector3>();
        }

        private class SerializableVector3
        {
            public float X;
            public float Y;
            public float Z;

            public SerializableVector3() { }
            public SerializableVector3(Vector3 value)
            {
                X = value.x;
                Y = value.y;
                Z = value.z;
            }

            public Vector3 ToVector3() => new Vector3(X, Y, Z);
        }

        private void Init()
        {
            LoadData();
        }

        private void OnServerInitialized()
        {
            ConsoleSystem.Run(ConsoleSystem.Option.Server, "relationshipmanager.maxteamsize", "0");
            foreach (BasePlayer player in BasePlayer.activePlayerList)
                ConfigurePlayer(player);
            foreach (BaseNetworkable entity in BaseNetworkable.serverEntities)
            {
                SleepingBag sleepingBag = entity as SleepingBag;
                if (sleepingBag != null)
                    RemoveBagCooldown(sleepingBag);
                BuildingPrivlidge cupboard = entity as BuildingPrivlidge;
                if (cupboard != null)
                    ExpandCupboardPrivilege(cupboard);
            }

            timer.Every(1f, ApplyHealthRegeneration);
            Puts("NixOS Core rules initialized.");
        }

        private void Unload()
        {
            SaveData();
            foreach (BasePlayer player in BasePlayer.activePlayerList)
            {
                player.SetMaxHealth(100f);
                if (player.health > 100f)
                    player.health = 100f;
            }
        }

        private void OnServerSave() => SaveData();

        private void OnPlayerConnected(BasePlayer player)
        {
            ConfigurePlayer(player);
            timer.Once(2f, () =>
            {
                if (player != null && player.IsConnected)
                    SendReply(player, "Welcome to NixOS LAN PvE. Type <color=#ffd479>/help</color> for rules and commands.");
            });
        }

        private void ConfigurePlayer(BasePlayer player)
        {
            if (player == null)
                return;

            player.Connection.authLevel = 2;
            player.SetPlayerFlag(BasePlayer.PlayerFlags.IsAdmin, true);
            ServerUsers.Set(player.userID, ServerUsers.UserGroup.Owner, player.displayName, "LAN automatic owner");
            player.SetMaxHealth(PlayerMaximumHealth);
            if (player.health > 0f && player.health < PlayerMaximumHealth)
                player.health = PlayerMaximumHealth;
            player.SendNetworkUpdateImmediate();

            GrantIfRegistered(player.UserIDString, BackpackPermission);
            GrantIfRegistered(player.UserIDString, RemoverPermission);
        }

        private void GrantIfRegistered(string userId, string permissionName)
        {
            if (permission.PermissionExists(permissionName) && !permission.UserHasPermission(userId, permissionName))
                permission.GrantUserPermission(userId, permissionName, null);
        }

        private void ApplyHealthRegeneration()
        {
            foreach (BasePlayer player in BasePlayer.activePlayerList)
            {
                if (player == null || player.IsDead() || player.IsWounded())
                    continue;

                player.SetMaxHealth(PlayerMaximumHealth);
                float previous;
                if (lastHealth.TryGetValue(player.userID, out previous) && player.health > previous && player.health < PlayerMaximumHealth)
                {
                    float vanillaGain = player.health - previous;
                    player.Heal(Mathf.Min(vanillaGain * 4f, PlayerMaximumHealth - player.health));
                }
                lastHealth[player.userID] = player.health;
            }
        }

        private object OnEntityTakeDamage(BaseCombatEntity entity, HitInfo info)
        {
            if (entity == null || info == null)
                return null;

            ulong attackerId = GetResponsiblePlayerId(info);
            BasePlayer victim = entity as BasePlayer;

            if (entity is BaseVehicle && info.damageTypes.Has(Rust.DamageType.Decay))
            {
                info.damageTypes.Scale(Rust.DamageType.Decay, 0f);
                if (info.damageTypes.Total() <= 0f)
                    return true;
            }

            if (attackerId == 0 && victim == null && IsPlayerOwnedEntity(entity))
                NotifyStructureOwner(entity, info);

            if (victim != null &&
                !(victim is NPCPlayer) &&
                attackerId != 0 &&
                attackerId != victim.userID)
            {
                info.damageTypes.Clear();
                return true;
            }

            if (victim != null && info.damageTypes.Has(Rust.DamageType.Radiation))
                info.damageTypes.Scale(Rust.DamageType.Radiation, 0.5f);

            if (attackerId != 0 && !(entity is BasePlayer) && IsPlayerOwnedEntity(entity))
            {
                bool ownsEntity = entity.OwnerID == attackerId;
                BuildingPrivlidge privilege = entity.GetBuildingPrivilege();
                bool buildingAuthorized = IsAuthorized(privilege, attackerId);
                if (!ownsEntity && !buildingAuthorized)
                {
                    info.damageTypes.Clear();
                    return true;
                }
            }

            return null;
        }

        private ulong GetResponsiblePlayerId(HitInfo info)
        {
            BasePlayer player = info.InitiatorPlayer;
            if (player != null)
                return player is NPCPlayer ? 0 : player.userID;

            BaseEntity source = info.Initiator as BaseEntity;
            if (source == null)
                return 0;
            if (source is NPCPlayer)
                return 0;

            BaseEntity parent = source.GetParentEntity();
            if (parent is NPCPlayer)
                return 0;
            if (source.OwnerID != 0)
                return source.OwnerID;

            return parent != null ? parent.OwnerID : 0;
        }

        private bool IsAuthorized(BuildingPrivlidge privilege, ulong playerId)
        {
            if (privilege == null)
                return false;

            foreach (ulong authorizedPlayerId in privilege.authorizedPlayers)
            {
                if (authorizedPlayerId == playerId)
                    return true;
            }
            return false;
        }

        private void NotifyStructureOwner(BaseCombatEntity entity, HitInfo info)
        {
            if (entity.OwnerID == 0 || entity.net == null)
                return;

            float previousAlert;
            ulong networkId = entity.net.ID.Value;
            if (lastStructureAlert.TryGetValue(networkId, out previousAlert) &&
                Time.realtimeSinceStartup - previousAlert < 60f)
                return;

            BasePlayer owner = BasePlayer.FindByID(entity.OwnerID);
            if (owner == null || !owner.IsConnected)
                return;

            lastStructureAlert[networkId] = Time.realtimeSinceStartup;
            string source = info.Initiator != null ? info.Initiator.ShortPrefabName : "the environment";
            SendReply(owner, string.Format(
                CultureInfo.InvariantCulture,
                "<color=#ff9c8f>Structure alert:</color> {0} took {1:0.0} damage from {2}.",
                entity.ShortPrefabName,
                info.damageTypes.Total(),
                source));
        }

        private bool IsPlayerOwnedEntity(BaseCombatEntity entity)
        {
            if (entity is BuildingBlock || entity is Door || entity is BuildingPrivlidge)
                return true;

            return entity.OwnerID != 0 && !(entity is BaseNpc);
        }

        private object OnTeamCreate(BasePlayer player)
        {
            SendReply(player, "Native teams are disabled on this PvE server.");
            return false;
        }

        private object OnTeamInvite(BasePlayer player, BasePlayer target)
        {
            SendReply(player, "Native teams are disabled on this PvE server.");
            return false;
        }

        private BasePlayer.SpawnPoint OnPlayerRespawn(BasePlayer player, BasePlayer.SpawnPoint spawnPoint)
        {
            if (spawnPoint == null || spawnPoint.pos == Vector3.zero)
                return ServerMgr.FindSpawnPoint();
            return spawnPoint;
        }

        private void OnPlayerRespawned(BasePlayer player)
        {
            if (player == null)
                return;

            player.SetMaxHealth(PlayerMaximumHealth);
            player.health = PlayerMaximumHealth;
            GiveRespawnLoadout(player);
        }

        private void OnEntitySpawned(SleepingBag sleepingBag)
        {
            if (sleepingBag != null)
                NextTick(() => RemoveBagCooldown(sleepingBag));
        }

        private void OnEntitySpawned(BuildingPrivlidge cupboard)
        {
            if (cupboard != null)
                NextTick(() => ExpandCupboardPrivilege(cupboard));
        }

        private void OnEntityBuilt(Planner planner, GameObject gameObject)
        {
            SleepingBag sleepingBag = gameObject?.GetComponent<SleepingBag>();
            if (sleepingBag != null)
                RemoveBagCooldown(sleepingBag);
        }

        private void RemoveBagCooldown(SleepingBag sleepingBag)
        {
            if (sleepingBag == null || sleepingBag.IsDestroyed)
                return;
            sleepingBag.secondsBetweenReuses = 0f;
            sleepingBagUnlockTime?.SetValue(sleepingBag, 0f);
        }

        private void ExpandCupboardPrivilege(BuildingPrivlidge cupboard)
        {
            if (cupboard == null || cupboard.IsDestroyed)
                return;

            Collider previous = null;
            float largestTrigger = -1f;
            foreach (Collider candidate in cupboard.GetComponentsInChildren<Collider>())
            {
                if (!candidate.isTrigger)
                    continue;
                float size = candidate.bounds.extents.sqrMagnitude;
                if (size > largestTrigger)
                {
                    previous = candidate;
                    largestTrigger = size;
                }
            }
            if (previous == null)
            {
                PrintWarning("Tool Cupboard is missing its privilege trigger.");
                return;
            }

            GameObject triggerObject = previous.gameObject;
            SphereCollider sphere = previous as SphereCollider;
            if (sphere == null)
            {
                UnityEngine.Object.Destroy(previous);
                sphere = triggerObject.AddComponent<SphereCollider>();
            }

            sphere.transform.localPosition = Vector3.zero;
            sphere.transform.localScale = Vector3.one;
            sphere.radius = 250f;
            sphere.isTrigger = true;
        }

        private void GiveRespawnLoadout(BasePlayer player)
        {
            Item rifle = ItemManager.CreateByName("rifle.ak", 1);
            if (rifle != null)
            {
                Item holo = ItemManager.CreateByName("weapon.mod.holosight", 1);
                Item flashlightMod = ItemManager.CreateByName("weapon.mod.flashlight", 1);
                if (rifle.contents != null)
                {
                    holo?.MoveToContainer(rifle.contents);
                    flashlightMod?.MoveToContainer(rifle.contents);
                }
                player.GiveItem(rifle);
            }

            Give(player, "ammo.rifle", 1000);
            GiveWear(player, "metal.facemask");
            GiveWear(player, "metal.plate.torso");
            GiveWear(player, "roadsign.kilt");
            GiveWear(player, "roadsign.gloves");
            GiveWear(player, "hoodie");
            GiveWear(player, "pants");
            GiveWear(player, "shoes.boots");
            Give(player, "hazmatsuit", 1);
            Give(player, "syringe.medical", 50);
            Give(player, "bandage", 20);
            Give(player, "largemedkit", 5);
            Give(player, "pickaxe.salvaged", 1);
            Give(player, "axe.salvaged", 1);
            Give(player, "hammer", 1);
            Give(player, "building.planner", 1);
            Give(player, "sleepingbag", 1);
            Give(player, "bearmeat.cooked", 20);
            GiveFullWaterJug(player);
            Give(player, "flashlight.held", 1);
            Give(player, "wood", 10000);
            Give(player, "stones", 10000);
            Give(player, "metal.fragments", 5000);
            Give(player, "cupboard.tool", 1);
            Give(player, "door.hinged.metal", 1);
            Give(player, "lock.code", 1);
        }

        private void GiveFullWaterJug(BasePlayer player)
        {
            Item jug = ItemManager.CreateByName("waterjug", 1);
            if (jug == null)
            {
                PrintWarning("Respawn item not found: waterjug");
                return;
            }

            player.GiveItem(jug);
            BaseLiquidVessel vessel = jug.GetHeldEntity() as BaseLiquidVessel;
            if (vessel != null)
                vessel.AddLiquid(ItemManager.FindItemDefinition("water"), 5000);
            else if (jug.contents != null)
                jug.contents.AddItem(ItemManager.FindItemDefinition("water"), 5000);
        }

        private void Give(BasePlayer player, string shortName, int amount)
        {
            Item item = ItemManager.CreateByName(shortName, amount);
            if (item == null)
            {
                PrintWarning("Respawn item not found: " + shortName);
                return;
            }
            player.GiveItem(item);
        }

        private void GiveWear(BasePlayer player, string shortName)
        {
            Item item = ItemManager.CreateByName(shortName, 1);
            if (item == null)
            {
                PrintWarning("Respawn wearable not found: " + shortName);
                return;
            }
            if (!item.MoveToContainer(player.inventory.containerWear))
                player.GiveItem(item);
        }

        private void OnEntityDeath(BasePlayer victim, HitInfo info)
        {
            if (victim == null || victim is NPCPlayer)
                return;

            storedData.LatestDeaths[victim.userID] = new SerializableVector3(victim.transform.position);
            SaveData();

            string cause = "environment";
            string weapon = "unknown";
            float distance = 0f;
            if (info != null)
            {
                if (info.InitiatorPlayer != null)
                    cause = info.InitiatorPlayer.displayName;
                else if (info.Initiator != null)
                    cause = info.Initiator.ShortPrefabName;

                if (info.Weapon != null)
                    weapon = info.Weapon.ShortPrefabName;
                else if (info.WeaponPrefab != null)
                    weapon = info.WeaponPrefab.ShortPrefabName;

                if (info.Initiator != null)
                    distance = Vector3.Distance(victim.transform.position, info.Initiator.transform.position);
            }

            PrintToChat(string.Format(
                CultureInfo.InvariantCulture,
                "<color=#ff9c8f>{0}</color> died to {1} with {2} at {3:0}m.",
                victim.displayName,
                cause,
                weapon,
                distance));
        }

        private void OnPlayerMarkersSend(BasePlayer player, ProtoBuf.MapNoteList markerList)
        {
            if (player == null || markerList?.notes == null)
                return;

            Dictionary<string, SerializableVector3> homes = GetHomes(player.userID);
            foreach (KeyValuePair<string, SerializableVector3> home in homes)
                AddPrivateMarker(markerList, home.Value.ToVector3(), "Home: " + home.Key, 0, 2);

            SerializableVector3 death;
            if (storedData.LatestDeaths.TryGetValue(player.userID, out death))
                AddPrivateMarker(markerList, death.ToVector3(), "Latest death", 5, 3);

            foreach (BaseNetworkable networkable in BaseNetworkable.serverEntities)
            {
                BaseEntity entity = networkable as BaseEntity;
                if (entity == null || entity.IsDestroyed)
                    continue;

                BaseVehicle vehicle = entity as BaseVehicle;
                if (vehicle != null && vehicle.OwnerID == player.userID)
                {
                    AddPrivateMarker(
                        markerList,
                        vehicle.transform.position,
                        "Owned " + vehicle.ShortPrefabName,
                        2,
                        4);
                    continue;
                }

                if (entity is BradleyAPC ||
                    entity is PatrolHelicopter ||
                    entity is CargoShip ||
                    entity is CH47HelicopterAIController)
                {
                    AddPrivateMarker(
                        markerList,
                        entity.transform.position,
                        "PvE event: " + entity.ShortPrefabName,
                        6,
                        1);
                }
            }
        }

        private void AddPrivateMarker(
            ProtoBuf.MapNoteList markerList,
            Vector3 position,
            string label,
            int icon,
            int colour)
        {
            markerList.notes.Add(new ProtoBuf.MapNote
            {
                noteType = 1,
                isPing = true,
                icon = icon,
                colourIndex = colour,
                worldPosition = position,
                label = label
            });
        }

        [ChatCommand("sethome")]
        private void SetHomeCommand(BasePlayer player, string command, string[] args)
        {
            if (args.Length != 1)
            {
                SendReply(player, "Usage: /sethome <name>");
                return;
            }

            string name = NormalizeHomeName(args[0]);
            Dictionary<string, SerializableVector3> homes = GetHomes(player.userID);
            if (!homes.ContainsKey(name) && homes.Count >= MaximumHomes)
            {
                SendReply(player, "You may save at most three homes.");
                return;
            }

            homes[name] = new SerializableVector3(player.transform.position);
            SaveData();
            SendReply(player, "Home <color=#ffd479>" + name + "</color> saved.");
        }

        [ChatCommand("home")]
        private void HomeCommand(BasePlayer player, string command, string[] args)
        {
            if (args.Length != 1)
            {
                SendReply(player, "Usage: /home <name>");
                return;
            }

            SerializableVector3 home;
            if (!GetHomes(player.userID).TryGetValue(NormalizeHomeName(args[0]), out home))
            {
                SendReply(player, "That home does not exist. Use /homes to list saved homes.");
                return;
            }

            player.Teleport(home.ToVector3());
            SendReply(player, "Teleported home.");
        }

        [ChatCommand("removehome")]
        private void RemoveHomeCommand(BasePlayer player, string command, string[] args)
        {
            if (args.Length != 1 || !GetHomes(player.userID).Remove(NormalizeHomeName(args[0])))
            {
                SendReply(player, "Usage: /removehome <existing-name>");
                return;
            }

            SaveData();
            SendReply(player, "Home removed.");
        }

        [ChatCommand("homes")]
        private void HomesCommand(BasePlayer player, string command, string[] args)
        {
            Dictionary<string, SerializableVector3> homes = GetHomes(player.userID);
            SendReply(player, homes.Count == 0
                ? "No homes saved."
                : "Homes: " + string.Join(", ", homes.Keys));
        }

        [ChatCommand("help")]
        private void HelpCommand(BasePlayer player, string command, string[] args)
        {
            SendReply(player,
                "<size=18><color=#ffd479>NixOS LAN PvE</color></size>\n" +
                "PvE only: player/sleeper damage and unauthorized structure damage are blocked.\n" +
                "Rates: 10,000x core materials, 2,500x components/electrical, and 75-100x other gather/loot.\n" +
                "Production: instant craft, 200x cooking, 10x cooker output, and 75% less cooker fuel.\n" +
                "Players: 200 health, boosted regeneration, half radiation, 48-slot persistent backpack.\n" +
                "Commands: /backpack, /remove, /sethome <name>, /home <name>, /homes, /removehome <name>.\n" +
                "Homes: 3 per player, instant, no cooldown. Native teams and player teleport are disabled.\n" +
                "Every LAN player is an owner/admin. Carbon panel: F1 then carbon.");
        }

        private string NormalizeHomeName(string value)
        {
            string result = value.Trim().ToLowerInvariant();
            return result.Length > 24 ? result.Substring(0, 24) : result;
        }

        private Dictionary<string, SerializableVector3> GetHomes(ulong userId)
        {
            Dictionary<string, SerializableVector3> homes;
            if (!storedData.Homes.TryGetValue(userId, out homes))
            {
                homes = new Dictionary<string, SerializableVector3>();
                storedData.Homes[userId] = homes;
            }
            return homes;
        }

        private void LoadData()
        {
            try
            {
                storedData = Interface.Oxide.DataFileSystem.ReadObject<StoredData>(Name);
            }
            catch (Exception exception)
            {
                PrintError("Could not read data; starting clean: " + exception.Message);
                storedData = new StoredData();
            }
            if (storedData == null)
                storedData = new StoredData();
        }

        private void SaveData()
        {
            Interface.Oxide.DataFileSystem.WriteObject(Name, storedData);
        }
    }
}
