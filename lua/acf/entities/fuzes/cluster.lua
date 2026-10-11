local Classes = ACF.Classes

Classes.DefineClass("ACF.Missiles.Fuze.Cluster", "ACF.Missiles.Fuze.Optical", function(CLASS)
    CLASS.Name = "Cluster"
    CLASS.Description = "This fuze fires a beam directly ahead and releases bomblets when the beam hits something close by. Distance in inches."

    CLASS.Spread = 30
    CLASS.MinDistance = 500
    CLASS.MaxDistance = 5000
    CLASS.MinBomblets = 1
    CLASS.MaxBomblets = 30

    if SERVER then
        local function PrepareBullet(Class, BulletData)
            local Caliber  = BulletData.Caliber
            local ProjMass = BulletData.ProjMass
            local Rows     = math.max(1, math.floor(ProjMass / Caliber))

            local BombletData = table.Copy(BulletData)

            BombletData.WeaponType = "ACF.Guns.Cannon"
            BombletData.Caliber    = Caliber
            BombletData.ProjMass   = ProjMass / Rows
            BombletData.PropMass   = 0
            BombletData.Bomblets   = math.Clamp(Rows, Class.MinBomblets, Class.MaxBomblets)

            return BombletData
        end

        function CLASS:HandleDetonation(Entity, BulletData)
            local RoundData = Entity.RoundData
            if not RoundData then return end

            local Bullet      = PrepareBullet(self, BulletData)
            local Bomblets    = Bullet.Bomblets
            local Velocity    = BulletData.Flight

            Bullet.Crate  = BulletData.Crate
            Bullet.Owner  = BulletData.Owner
            Bullet.Gun    = BulletData.Gun
            Bullet.Pos    = BulletData.Pos
            Bullet.Flight = Velocity
            Bullet.Filter = BulletData.Filter

            RoundData:Network(Entity, Bullet)

            local EffectTable = {
                Origin = Entity.Position,
                Normal = Entity.CurDir,
                Scale  = math.max(Bomblets ^ 0.33 * ACF.MeterToInch, 1),
            }
            ACF.Utilities.Effects.CreateEffect("ACF_Explosion", EffectTable)

            for _ = 1, Bomblets do
                local Cone = math.tan(math.rad(self.Spread * ACF.GunInaccuracyScale))
                local Spread = (Entity:GetUp() * math.Rand(-1, 1) + Entity:GetRight() * math.Rand(-1, 1)):GetNormalized()
                local ShootDir = (Velocity:GetNormalized() + Cone * Spread * (math.random() ^ (1 / ACF.GunInaccuracyBias))):GetNormalized()

                Bullet.Flight = ShootDir * Velocity:Length()

                RoundData:Create(Entity, Bullet)
            end
        end
    end
end)

do -- Add cluster fuzes as an option to existing missile classes
    local AddClusterFuzeByGroup = {
        ["ACF.Missiles.FreeFallingBomb"] = true,
        ["ACF.Missiles.GlidingBomb"] = true,
    }

    local AddClusterFuzeByClass = {
        ["ACF.Missiles.GuidedBomb.227kg"] = true,
        ["ACF.Missiles.GuidedBomb.454kg"] = true,
        ["ACF.Missiles.GuidedBomb.909kg"] = true,
        ["ACF.Missiles.Artillery.SAKR-10"] = true,
        ["ACF.Missiles.Artillery.SS-40"] = true
    }

    hook.Add("ACF_OnLoadAddon", "ACF_LoadClusterMunitions", function()
        for Base in pairs(AddClusterFuzeByGroup) do
            for _, Class in pairs(Classes.GetSubtypes(Base)) do
                if Class then
                    Class.Fuzes["ACF.Missiles.Fuze.Cluster"] = true
                end
            end
        end

        for ClassName in pairs(AddClusterFuzeByClass) do
            local Class = Classes.GetTypeByName(ClassName)

            if Class then
                Class.Fuzes["ACF.Missiles.Fuze.Cluster"] = true
            end
        end
    end)
end