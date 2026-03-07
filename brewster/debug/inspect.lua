-- Save as inspect.lua
local chest = peripheral.find("minecraft:chest")
local stand = peripheral.find("minecraft:brewing_stand")

print("--- CHEST SLOT 1 ---")
local d = chest.getItemDetail(1)
if d then
    print("Name: " .. d.name)
    print("Display: [" .. (d.displayName or "NIL") .. "]")
    if d.nbt then print("NBT: " .. textutils.serialize(d.nbt)) end
    if d.components then print("COMP: " .. textutils.serialize(d.components)) end
else
    print("Slot 1 is empty!")
end

print("\n--- STAND SLOT 1 ---")
local s = stand.getItemDetail(1)
if s then
    print("Display: [" .. (s.displayName or "NIL") .. "]")
else
    print("Stand is empty!")
end
