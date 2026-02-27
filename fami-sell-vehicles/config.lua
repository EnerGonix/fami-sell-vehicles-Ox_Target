Config = {}

Config.SellPoint = {
    blipSprite = 147,
    blipColor = 52,
    blipScale = 0.8,
    blipShortRange = true,
    blipPos = vector3(-23.2987, -1678.4564, 29.4658),

    markerType = 36,
    markerColor = { r = 10, g = 255, b = 0, a = 80 },
    markerWidth = 1.0,
    markerHeight = 1.0,
    markerPos = vector3(-23.2987, -1678.4564, 29.4658),
    markerShowRadius = 10.0,
}

Config.ViewVehicles = {
    main = {
        position = vector4(-40.5096, -1689.4296, 28.7218, 339.1792),
        spawnDistance = 30.0
    },

    extras = {
        vector4(-44.2595, -1690.4960, 28.7473, 345.3205),
        vector4(-48.0431, -1691.4502, 28.8070, 348.6477),
        vector4(-51.8795, -1693.2780, 28.8551, 345.4077),
        vector4(-55.8660, -1691.7886, 28.8556, 318.3111),
        vector4(-58.4272, -1689.5544, 28.8554, 314.6123),
        vector4(-59.9639, -1686.6311, 28.8514, 279.6702),
        vector4(-58.1895, -1683.4033, 28.8533, 280.0444),
        vector4(-55.8359, -1680.6615, 28.8391, 279.9881),
        vector4(-53.3807, -1677.5134, 28.7439, 280.9263)
    }
}

Config.ReturnCarToOwnerTax = 0.1 -- 10% tax for taking the car from the dealership
Config.SellCarTax = 0.1 -- 10% tax for selling the car to the dealership