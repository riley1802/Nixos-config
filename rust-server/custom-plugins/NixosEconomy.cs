using System;
using System.Collections.Generic;
using Oxide.Core;
using Oxide.Game.Rust.Cui;
using UnityEngine;

namespace Oxide.Plugins
{
    [Info("NixosEconomy", "NixOS", "1.0.0")]
    [Description("Gathering, loot, inventory, crafting, cooking, and durability rates.")]
    public class NixosEconomy : RustPlugin
    {
        private const int MaximumStack = 100000000;
        private readonly Dictionary<int, int> originalStackSizes = new Dictionary<int, int>();
        private readonly Dictionary<ItemModCookable, float> originalCookTimes =
            new Dictionary<ItemModCookable, float>();
        private readonly Dictionary<ItemModCookable, float> originalCookAmounts =
            new Dictionary<ItemModCookable, float>();
        private readonly Dictionary<ItemModBurnable, float> originalFuelAmounts =
            new Dictionary<ItemModBurnable, float>();
        private readonly HashSet<ulong> boostedCorpses = new HashSet<ulong>();
        private readonly HashSet<ItemContainer> splittingContainers = new HashSet<ItemContainer>();
        private readonly Dictionary<ItemContainer, BasePlayer> lastContainerPlayer =
            new Dictionary<ItemContainer, BasePlayer>();
        private readonly Dictionary<ulong, Dictionary<string, long>> gathered =
            new Dictionary<ulong, Dictionary<string, long>>();
        private readonly HashSet<ulong> gatherHudScheduled = new HashSet<ulong>();
        private readonly HashSet<HackableLockedCrate> chinookCrates =
            new HashSet<HackableLockedCrate>();
        private readonly HashSet<BaseFishingRod> activeFishingRods =
            new HashSet<BaseFishingRod>();

        private void OnServerInitialized()
        {
            ApplyItemDefinitions();
            foreach (BaseNetworkable entity in BaseNetworkable.serverEntities)
            {
                BaseOven oven = entity as BaseOven;
                if (oven != null)
                    ExpandOven(oven);
                MiningQuarry quarry = entity as MiningQuarry;
                if (quarry != null)
                    SpeedQuarry(quarry);
                ExcavatorArm excavator = entity as ExcavatorArm;
                if (excavator != null)
                    SpeedExcavator(excavator);
            }
            Puts("NixOS economy rates initialized.");
        }

        private void Unload()
        {
            foreach (ItemDefinition definition in ItemManager.itemList)
            {
                int stackSize;
                if (originalStackSizes.TryGetValue(definition.itemid, out stackSize))
                    definition.stackable = stackSize;

                ItemModCookable cookable = definition.GetComponent<ItemModCookable>();
                float cookTime;
                float cookAmount;
                if (cookable != null && originalCookTimes.TryGetValue(cookable, out cookTime))
                {
                    cookable.cookTime = cookTime;
                    if (originalCookAmounts.TryGetValue(cookable, out cookAmount))
                        cookable.amountOfBecome = cookAmount;
                }

                ItemModBurnable burnable = definition.GetComponent<ItemModBurnable>();
                float fuelAmount;
                if (burnable != null && originalFuelAmounts.TryGetValue(burnable, out fuelAmount))
                    burnable.fuelAmount = fuelAmount;
            }

            foreach (BaseNetworkable entity in BaseNetworkable.serverEntities)
            {
                MiningQuarry quarry = entity as MiningQuarry;
                if (quarry != null)
                    quarry.processRate = 5f;
                ExcavatorArm excavator = entity as ExcavatorArm;
                if (excavator != null)
                    excavator.resourceProductionTickRate = 3f;
            }
        }

        private void ApplyItemDefinitions()
        {
            foreach (ItemDefinition definition in ItemManager.itemList)
            {
                if (!originalStackSizes.ContainsKey(definition.itemid))
                    originalStackSizes[definition.itemid] = definition.stackable;

                if (IsFungible(definition))
                    definition.stackable = MaximumStack;

                ItemModCookable cookable = definition.GetComponent<ItemModCookable>();
                if (cookable != null)
                {
                    if (!originalCookTimes.ContainsKey(cookable))
                    {
                        originalCookTimes[cookable] = cookable.cookTime;
                        originalCookAmounts[cookable] = cookable.amountOfBecome;
                    }
                    cookable.cookTime = Math.Max(0.01f, originalCookTimes[cookable] / 200f);
                    cookable.amountOfBecome = Math.Max(1f, originalCookAmounts[cookable] * 5f);
                }

                ItemModBurnable burnable = definition.GetComponent<ItemModBurnable>();
                if (burnable != null)
                {
                    if (!originalFuelAmounts.ContainsKey(burnable))
                        originalFuelAmounts[burnable] = burnable.fuelAmount;
                    burnable.fuelAmount = Math.Max(0.01f, originalFuelAmounts[burnable] / 200f);
                }
            }
        }

        private bool IsFungible(ItemDefinition definition)
        {
            if (definition.stackable <= 1 || definition.condition.enabled)
                return false;

            switch (definition.category)
            {
                case ItemCategory.Weapon:
                case ItemCategory.Attire:
                case ItemCategory.Tool:
                    return false;
                default:
                    return true;
            }
        }

        private void OnEntitySpawned(BaseOven oven)
        {
            if (oven != null)
                NextTick(() => ExpandOven(oven));
        }

        private void OnEntitySpawned(MiningQuarry quarry)
        {
            if (quarry != null)
                NextTick(() => SpeedQuarry(quarry));
        }

        private void OnEntitySpawned(ExcavatorArm excavator)
        {
            if (excavator != null)
                NextTick(() => SpeedExcavator(excavator));
        }

        private void OnQuarryEnabled(MiningQuarry quarry)
        {
            SpeedQuarry(quarry);
        }

        private void SpeedQuarry(MiningQuarry quarry)
        {
            if (quarry == null || quarry.IsDestroyed)
                return;
            quarry.processRate = 0.5f;
            if (quarry.IsOn())
            {
                quarry.CancelInvoke(quarry.ProcessResources);
                quarry.InvokeRepeating(quarry.ProcessResources, 0.5f, 0.5f);
            }
        }

        private void SpeedExcavator(ExcavatorArm excavator)
        {
            if (excavator == null || excavator.IsDestroyed)
                return;
            excavator.resourceProductionTickRate = 0.3f;
            if (excavator.IsOn())
            {
                excavator.CancelInvoke(excavator.ProduceResources);
                excavator.InvokeRepeating(excavator.ProduceResources, 0.3f, 0.3f);
            }
        }

        private void ExpandOven(BaseOven oven)
        {
            if (oven == null || oven.IsDestroyed || oven.inventory == null)
                return;

            int vanillaCapacity = oven.inventory.capacity;
            if (vanillaCapacity > 0 && vanillaCapacity < 48)
            {
                oven.inventory.capacity = Math.Min(vanillaCapacity * 3, 48);
                oven.inventory.MarkDirty();
            }
        }

        private void OnDispenserGather(ResourceDispenser dispenser, BasePlayer player, Item item)
        {
            Multiply(item, 100);
            RecordGather(player, item);
        }

        private void OnDispenserBonus(ResourceDispenser dispenser, BasePlayer player, Item item)
        {
            Multiply(item, 100);
            RecordGather(player, item);
        }

        private void OnCollectiblePickup(CollectibleEntity collectible, BasePlayer player, bool eat)
        {
            if (collectible == null || collectible.itemList == null)
                return;

            foreach (ItemAmount output in collectible.itemList)
            {
                output.amount *= 75f;
                RecordGather(player, output.itemDef, Mathf.RoundToInt(output.amount));
            }
        }

        private void OnGrowableGathered(GrowableEntity growable, Item item, BasePlayer player)
        {
            Multiply(item, 75);
            RecordGather(player, item);
        }

        private void OnQuarryGather(MiningQuarry quarry, Item item)
        {
            Multiply(item, 75);
        }

        private void OnExcavatorGather(ExcavatorArm excavator, Item item)
        {
            Multiply(item, 75);
        }

        private void OnSurveyGather(SurveyCharge charge, Item item)
        {
            Multiply(item, 75);
        }

        private void OnFishCatch(Item fish, BaseFishingRod fishingRod, BasePlayer player)
        {
            Multiply(fish, 75);
            RecordGather(player, fish);
        }

        private void OnFishingRodCast(BaseFishingRod fishingRod, BasePlayer player)
        {
            if (fishingRod != null)
                activeFishingRods.Add(fishingRod);
        }

        private void OnFishingStopped(BaseFishingRod fishingRod, BaseFishingRod.FailReason reason)
        {
            activeFishingRods.Remove(fishingRod);
        }

        private void OnFishCaught(ItemDefinition fish, BaseFishingRod fishingRod, BasePlayer player)
        {
            activeFishingRods.Remove(fishingRod);
        }

        private void OnTick()
        {
            if (activeFishingRods.Count == 0)
                return;

            List<BaseFishingRod> invalid = null;
            foreach (BaseFishingRod rod in activeFishingRods)
            {
                if (rod == null || rod.IsDestroyed)
                {
                    if (invalid == null)
                        invalid = new List<BaseFishingRod>();
                    invalid.Add(rod);
                    continue;
                }

                for (int extraTick = 0; extraTick < 4; extraTick++)
                    rod.CatchProcessBudgeted();
            }

            if (invalid != null)
            {
                foreach (BaseFishingRod rod in invalid)
                    activeFishingRods.Remove(rod);
            }
        }

        private void RecordGather(BasePlayer player, Item item)
        {
            if (item != null)
                RecordGather(player, item.info, item.amount);
        }

        private void RecordGather(BasePlayer player, ItemDefinition definition, int amount)
        {
            if (player == null || definition == null || amount <= 0)
                return;

            Dictionary<string, long> playerGather;
            if (!gathered.TryGetValue(player.userID, out playerGather))
            {
                playerGather = new Dictionary<string, long>();
                gathered[player.userID] = playerGather;
            }

            long current;
            playerGather.TryGetValue(definition.displayName.english, out current);
            playerGather[definition.displayName.english] = current + amount;
            if (!gatherHudScheduled.Add(player.userID))
                return;

            timer.Once(1f, () => ShowGatherHud(player));
        }

        private void ShowGatherHud(BasePlayer player)
        {
            if (player == null)
                return;

            Dictionary<string, long> playerGather;
            if (!gathered.TryGetValue(player.userID, out playerGather))
                return;

            List<string> lines = new List<string>();
            foreach (KeyValuePair<string, long> entry in playerGather)
                lines.Add(entry.Key + " +" + entry.Value.ToString("N0"));
            gathered.Remove(player.userID);
            gatherHudScheduled.Remove(player.userID);

            const string hudName = "NixosGatherHud";
            CuiHelper.DestroyUi(player, hudName);
            CuiElementContainer elements = new CuiElementContainer();
            elements.Add(new CuiPanel
            {
                Image = { Color = "0.08 0.08 0.08 0.78" },
                RectTransform = { AnchorMin = "0.77 0.70", AnchorMax = "0.98 0.88" },
                CursorEnabled = false
            }, "Hud", hudName);
            elements.Add(new CuiLabel
            {
                Text =
                {
                    Text = string.Join("\n", lines),
                    FontSize = 14,
                    Align = TextAnchor.MiddleRight,
                    Color = "0.95 0.85 0.55 1"
                },
                RectTransform = { AnchorMin = "0.05 0.05", AnchorMax = "0.95 0.95" }
            }, hudName);
            CuiHelper.AddUi(player, elements);
            timer.Once(3f, () =>
            {
                if (player != null)
                    CuiHelper.DestroyUi(player, hudName);
            });
        }

        private object CanAcceptItem(ItemContainer container, Item item, int targetPosition, BasePlayer player)
        {
            if (container?.entityOwner is BaseOven && player != null)
                lastContainerPlayer[container] = player;
            return null;
        }

        private void OnItemAddedToContainer(ItemContainer container, Item item)
        {
            BaseOven oven = container?.entityOwner as BaseOven;
            if (oven == null || item == null || splittingContainers.Contains(container))
                return;

            ItemModCookable cookable = item.info.GetComponent<ItemModCookable>();
            if (cookable == null)
                return;

            NextTick(() =>
            {
                if (item == null || item.parent != container)
                    return;
                int totalCookableAmount = item.amount;
                SplitCookableInput(container, item);
                InsertCalculatedFuel(oven, container, totalCookableAmount, cookable);
            });
        }

        private void SplitCookableInput(ItemContainer container, Item item)
        {
            List<int> freeSlots = new List<int>();
            int maximumInputSlots = Math.Max(1, container.capacity - 3);
            for (int slot = 0; slot < maximumInputSlots; slot++)
            {
                if (container.GetSlot(slot) == null)
                    freeSlots.Add(slot);
            }

            int splitCount = Math.Min(freeSlots.Count + 1, item.amount);
            if (splitCount <= 1)
                return;

            splittingContainers.Add(container);
            try
            {
                int amountPerStack = item.amount / splitCount;
                for (int index = 0; index < splitCount - 1; index++)
                {
                    Item split = item.SplitItem(amountPerStack);
                    if (split == null || !split.MoveToContainer(container, freeSlots[index], false))
                        split?.MoveToContainer(container);
                }
            }
            finally
            {
                splittingContainers.Remove(container);
            }
        }

        private void InsertCalculatedFuel(
            BaseOven oven,
            ItemContainer container,
            int cookableAmount,
            ItemModCookable cookable)
        {
            BasePlayer player;
            if (oven.fuelType == null ||
                !lastContainerPlayer.TryGetValue(container, out player) ||
                player == null)
                return;

            ItemModBurnable burnable = oven.fuelType.GetComponent<ItemModBurnable>();
            if (burnable == null || burnable.fuelAmount <= 0f)
                return;

            int required = Mathf.CeilToInt(cookable.cookTime * cookableAmount / burnable.fuelAmount);
            int present = 0;
            foreach (Item existing in container.itemList)
            {
                if (existing.info == oven.fuelType)
                    present += existing.amount;
            }
            required -= present;
            if (required <= 0)
                return;

            List<Item> fuelSources = new List<Item>();
            player.inventory.FindItemsByItemID(fuelSources, oven.fuelType.itemid);
            if (fuelSources.Count == 0)
                return;

            Item source = fuelSources[0];
            Item fuel = source.SplitItem(Math.Min(required, source.amount));
            if (fuel != null && !fuel.MoveToContainer(container))
                player.GiveItem(fuel);
        }

        private void Multiply(Item item, int multiplier)
        {
            if (item == null || multiplier <= 1)
                return;

            long amount = (long)item.amount * multiplier;
            item.amount = (int)Math.Min(amount, MaximumStack);
        }

        private object OnItemCraft(ItemCraftTask task, BasePlayer player, Item fromTempBlueprint)
        {
            if (task == null || task.cancelled || task.blueprint == null || player == null)
                return null;

            long requested = (long)task.amount * task.blueprint.amountToCreate;
            int maximumResultStack = Math.Max(
                1,
                Math.Min(task.blueprint.targetItem.stackable, MaximumStack));
            while (requested > 0)
            {
                int amount = (int)Math.Min(requested, maximumResultStack);
                Item result = ItemManager.Create(task.blueprint.targetItem, amount, (ulong)task.skinID);
                if (result == null)
                    break;
                player.GiveItem(result);
                requested -= amount;
            }

            task.cancelled = true;
            return false;
        }

        private void OnItemResearch(ResearchTable researchTable, Item targetItem, BasePlayer player)
        {
            if (researchTable != null)
                researchTable.researchDuration = 0.1f;
        }

        private void OnLoseCondition(Item item, ref float amount)
        {
            amount *= 0.1f;
        }

        private void OnLootSpawn(LootContainer container)
        {
            if (container == null || container.inventory == null)
                return;

            NextTick(() => BoostLoot(container));
        }

        private void OnCrateDropped(HackableLockedCrate crate)
        {
            if (crate != null)
                chinookCrates.Add(crate);
        }

        private void BoostLoot(LootContainer container)
        {
            if (container == null || container.IsDestroyed || container.inventory == null)
                return;

            string prefab = container.ShortPrefabName.ToLowerInvariant();
            HackableLockedCrate lockedCrate = container as HackableLockedCrate;
            bool majorReward =
                prefab.Contains("supply") ||
                prefab.Contains("bradley") ||
                prefab.Contains("heli_crate") ||
                prefab.Contains("cargoship") ||
                (lockedCrate != null && chinookCrates.Contains(lockedCrate)) ||
                container.GetParentEntity() is CargoShip;
            int quantityMultiplier = majorReward ? 100 : 75;

            List<Item> originalItems = new List<Item>(container.inventory.itemList);
            int targetCapacity = Math.Max(container.inventory.capacity, originalItems.Count * 3);
            container.inventory.capacity = Math.Min(targetCapacity, 48);

            foreach (Item item in originalItems)
            {
                if (item == null)
                    continue;
                if (item.info.shortname == "blueprintbase")
                {
                    item.Remove();
                    continue;
                }

                if (IsFungible(item.info))
                    Multiply(item, item.info.shortname == "scrap" ? 75 : quantityMultiplier);
                int copyCount = IsRare(item.info) ? 8 : 2;
                for (int copyIndex = 0; copyIndex < copyCount; copyIndex++)
                {
                    Item copy = ItemManager.Create(item.info, item.amount, item.skin);
                    if (copy != null && !copy.MoveToContainer(container.inventory))
                        copy.Remove();
                }
            }

            container.inventory.MarkDirty();
            container.minSecondsBetweenRefresh = Math.Max(1f, container.minSecondsBetweenRefresh / 5f);
            container.maxSecondsBetweenRefresh = Math.Max(1f, container.maxSecondsBetweenRefresh / 5f);
        }

        private bool IsRare(ItemDefinition definition)
        {
            string rarity = definition.rarity.ToString();
            return rarity == "Rare" || rarity == "VeryRare";
        }

        private void OnCorpsePopulate(NPCPlayer npc, NPCPlayerCorpse corpse)
        {
            if (corpse != null)
                NextTick(() => BoostCorpse(corpse));
        }

        private void OnCorpsePopulate(BaseEntity owner, LootableCorpse corpse)
        {
            if (owner is BaseNpc && corpse != null)
                NextTick(() => BoostCorpse(corpse));
        }

        private void BoostCorpse(LootableCorpse corpse)
        {
            if (corpse == null || corpse.IsDestroyed || corpse.containers == null)
                return;
            if (corpse.net != null && !boostedCorpses.Add(corpse.net.ID.Value))
                return;

            foreach (ItemContainer container in corpse.containers)
            {
                if (container == null)
                    continue;

                List<Item> originalItems = new List<Item>(container.itemList);
                container.capacity = Math.Min(48, Math.Max(container.capacity, originalItems.Count * 3));
                foreach (Item item in originalItems)
                {
                    if (item == null || item.info.shortname == "blueprintbase")
                    {
                        item?.Remove();
                        continue;
                    }

                    if (IsFungible(item.info))
                        Multiply(item, 75);
                    int copyCount = IsRare(item.info) ? 8 : 2;
                    for (int copyIndex = 0; copyIndex < copyCount; copyIndex++)
                    {
                        Item copy = ItemManager.Create(item.info, item.amount, item.skin);
                        if (copy != null && !copy.MoveToContainer(container))
                            copy.Remove();
                    }
                }
                container.MarkDirty();
            }
        }

        private void OnItemDropped(Item item, BaseEntity entity)
        {
            if (entity == null)
                return;
            entity.CancelInvoke("IdleDestroy");
            entity.Invoke("IdleDestroy", item.GetDespawnDuration() * 5f);
        }
    }
}
