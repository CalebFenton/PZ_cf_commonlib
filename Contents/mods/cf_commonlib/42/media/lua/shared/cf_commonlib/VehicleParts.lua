local VehicleParts = {}

--- Whether the door part `partId` of `vehicle` leaves what it covers open: the door open, taken
--- off, or no such part or door at all.
function VehicleParts.isOpen(vehicle, partId)
    local part = vehicle:getPartById(partId)
    local door = part and part:getDoor()
    return not (door and part:getInventoryItem()) or door:isOpen()
end

return VehicleParts
