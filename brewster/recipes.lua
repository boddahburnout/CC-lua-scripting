return {
    -- BASES
    ["awkward"] = { ingredient = "minecraft:nether_wart", base = "minecraft:water" },
    
    -- POSITIVE POTIONS
    ["strength"] = { ingredient = "minecraft:blaze_powder", base = "awkward" },
    ["speed"] = { ingredient = "minecraft:sugar", base = "awkward" },
    ["fire_resistance"] = { ingredient = "minecraft:magma_cream", base = "awkward" },
    ["healing"] = { ingredient = "minecraft:glistering_melon_slice", base = "awkward" },
    ["regeneration"] = { ingredient = "minecraft:ghast_tear", base = "awkward" },
    ["night_vision"] = { ingredient = "minecraft:golden_carrot", base = "awkward" },
    ["invisibility"] = { ingredient = "minecraft:fermented_spider_eye", base = "night_vision" },
    ["slow_falling"] = { ingredient = "minecraft:phantom_membrane", base = "awkward" },
    
    -- NEGATIVE POTIONS
    ["weakness"] = { ingredient = "minecraft:fermented_spider_eye", base = "minecraft:water" },
    ["poison"] = { ingredient = "minecraft:spider_eye", base = "awkward" },
    ["slowness"] = { ingredient = "minecraft:fermented_spider_eye", base = "speed" },
    ["harming"] = { ingredient = "minecraft:fermented_spider_eye", base = "healing" }
}
