// ============================================================================
// TLH v45.9 - estabilidad de cambio de arma
// CUSTOM DUAL-WIELD BIND / PROCEDURAL WEAPON PRESENTATION / HELMET INTERIOR HUD
//
// Dual-wield remains on its custom KEYCONF netevent; Reload is still weapon-specific.
// Native weapon states remain authoritative; TacticalPlayer applies reversible
// procedural PSprite transforms for visual motion. Dual Wield is activated
// through the custom KEYCONF netevent.
// Hellfire uses the Rocket Launcher sprite family at reduced HUD/drop scale.
// ============================================================================

version "4.14"

// Custom PSprite layer used for dual-wielded/recycled weapon sprites.
const TLH_AKIMBO_LAYER = 2;
const TLH_STOWED_LAYER = 3; // dedicated folded-launcher overlay; keep PSP_FLASH (1) free
// ZScript trig uses degrees; this converts authored radian-based time phases.
const TLH_RAD_TO_DEG = 57.29577951308232;

// Global tactical limits. These are deliberately centralized so weapons,
// pickups, game modes and HUD logic all agree on the same ceilings.
const TLH_MAX_HEALTH = 800;
const TLH_MAX_ARMOR = 600;
const TLH_MAX_BULLETS = 300;
const TLH_MAX_SHELLS = 100;
const TLH_MAX_ROCKETS = 50;
const TLH_MAX_CELLS = 300;

// The Last Hope gameplay modes. The actual selector is the user CVar
// "tlh_gamemode" defined in CVARINFO.
// 0 Tactical Standard
// 1 Classic Doom
// 2 Hardcore
// 3 Glass Cannon
// 4 Bulletstorm
// 5 Infinite Ammo
// 6 Berserker
// 7 Low Gravity
// 8 High Gravity
// 9 Speedrun
// 10 Pistol Start
// 11 Shotgun Start
// 12 M4A1 Start
// 13 M60 Start
// 14 Random Arsenal
// 15 Horde
// 16 Arena
// 17 Survival
// 18 No Powerups
// 19 SSG Lockdown
// 20 One Shot
// 21 Monster Frenzy
// 22 Fragile Monsters
// 23 Super Heavy
// 24 Chaos
// 25 No Armor
// 26 Ammo Scarcity
// 27 Pacifist
// 28 Warzone
// 29 Weapon Roulette
// 30 Last Stand
// 31 Double Spawn
// 32 Nightmare Lite
// 33 Training

// ============================================================================
// THE LAST HOPE WAD - TACTICAL ARSENAL / ENHANCED ZSCRIPT v40.1
// Target: GZDoom g4.14.x / g4.14.2
// ============================================================================
// v40.1: hotfix for armor scope and No Powerups pickup class names.
// v41.5: modular edge-aligned helmet HUD plus layered procedural first-person weapon motion, weapon profiles, state-wide sprite scaling, advanced headbob, live hostile telemetry, distance-scaled target text,
// nerfed full-kit loot, stronger game-mode transitions, menu-ready CVars, and safer runtime enforcement. All custom enemy variants use
// valid GZDoom 4.14.2 actor bases such as DoomImp, Fatso, Arachnotron, Revenant,
// HellKnight, BaronOfHell and Cacodemon.
// Esta versión conserva la estructura y la intención del script original,
// pero corrige consumo de munición, estados muertos, overlays, trazas del HUD,
// cadenas 3D por tick, comportamiento de la baliza orbital y varios detalles
// de ergonomía/feedback.
// ============================================================================

// ============================================================================
// 0. RENDERIZADO PIXEL-ART
// ============================================================================

class CrispPixelArtHandler : EventHandler
{
    // gl_texture_filter is a protected engine CVAR in GZDoom and cannot
    // be changed from gameplay/UI ZScript. Keep this handler registered
    // for compatibility, but do not attempt to modify the CVAR here.
}

// ============================================================================
// 0.5. MUNICION TACTICA / LIMITES AMPLIADOS
// ============================================================================
// These replacements keep the vanilla class names used by the arsenal while
// raising their carry limits. This is important because GiveInventory() will
// otherwise respect the original Doom caps.

class TLHClipAmmo : Clip replaces Clip
{
    Default
    {
        Inventory.MaxAmount TLH_MAX_BULLETS;
    }
}

class TLHShellAmmo : Shell replaces Shell
{
    Default
    {
        Inventory.MaxAmount TLH_MAX_SHELLS;
    }
}

class TLHRocketAmmo : RocketAmmo replaces RocketAmmo
{
    Default
    {
        Inventory.MaxAmount TLH_MAX_ROCKETS;
    }
}

class TLHCellAmmo : Cell replaces Cell
{
    Default
    {
        Inventory.MaxAmount TLH_MAX_CELLS;
    }
}

// ============================================================================
// 1. PROYECTILES Y EFECTOS VISUALES
// ============================================================================

class SlideSmoke : Actor
{
    Default
    {
        +NOINTERACTION
        +NOGRAVITY
        RenderStyle "Translucent";
        Alpha 0.6;
        Scale 0.4;
    }

    States
    {
    Spawn:
        PUFF ABC 3 A_FadeOut(0.1);
        Stop;
    }
}

class SlamExplosion : Actor
{
    Default
    {
        +NOBLOCKMAP
        +NOGRAVITY
        +NOCLIP
    }

    States
    {
    Spawn:
        TNT1 A 1;
        TNT1 A 1
        {
            A_Explode(150, 192);
            A_RadiusThrust(600, 192, RTF_NOIMPACTDAMAGE);
            A_StartSound("cyber/hoof", CHAN_BODY);
            A_Quake(5, 15, 0, 400);
        }
        Stop;
    }
}

class MicroMissile : Rocket
{
    Default
    {
        Speed 40;
        DamageFunction(random(10, 15));
        Scale 0.35;
        Radius 5;
        Height 5;
        +SEEKERMISSILE
    }

    States
    {
    Spawn:
        MISL A 1 Bright A_SeekerMissile(5, 10, SMF_LOOK);
        Loop;
    Death:
        MISL B 6 Bright A_Explode(32, 64);
        MISL C 4 Bright;
        MISL D 4 Bright;
        Stop;
    }
}

class TrackingMicroMissile : Rocket
{
    Default
    {
        Speed 45;
        DamageFunction(random(15, 25));
        Scale 0.35;
        Radius 4;
        Height 4;
        +SEEKERMISSILE
    }

    States
    {
    Spawn:
        MISL A 1 Bright
        {
            A_SeekerMissile(20, 40, SMF_LOOK | SMF_PRECISE);
        }
        Loop;
    Death:
        MISL B 6 Bright
        {
            A_Explode(45, 80);
            A_StartSound("weapons/rocklx", CHAN_WEAPON);
            A_Quake(2, 6, 0, 200);
        }
        MISL C 4 Bright;
        MISL D 4 Bright;
        Stop;
    }
}

class ShotgunSlug : FastProjectile
{
    Default
    {
        Speed 120;
        Radius 2;
        Height 2;
        DamageFunction(random(40, 50));
        +RIPPER
        +BLOODSPLATTER
    }

    States
    {
    Spawn:
        PUFF A 1 Bright;
        Loop;
    Death:
        PUFF B 4 Bright;
        PUFF C 4;
        Stop;
    }
}

class FlakGrenade : Actor
{
    Default
    {
        Radius 4;
        Height 4;
        Speed 30;
        Damage 15;
        Scale 0.3;
        Projectile;
        -NOGRAVITY
        +USEBOUNCESTATE
        BounceType "Doom";
        BounceFactor 0.7;
        WallBounceFactor 0.7;
        Gravity 0.8;
    }

    States
    {
    Spawn:
        MISL A 1 Bright;
        Loop;
    Bounce:
        MISL A 0 A_StartSound("weapons/sshoto", CHAN_BODY);
        Goto Spawn;
    Death:
        MISL B 4 Bright A_Explode(30, 80);
        MISL C 4 Bright;
        MISL D 4 Bright;
        Stop;
    }
}

class OfficerHeavyGrenade : Actor
{
    Default
    {
        Radius 6;
        Height 6;
        Speed 35;
        Damage 20;
        Scale 0.4;
        Projectile;
        -NOGRAVITY
        +USEBOUNCESTATE
        BounceType "Doom";
        BounceFactor 0.5;
        WallBounceFactor 0.5;
        Gravity 0.9;
    }

    States
    {
    Spawn:
        MISL A 1 Bright;
        Loop;
    Bounce:
        MISL A 0 A_StartSound("weapons/sshoto", CHAN_BODY);
        Goto Spawn;
    Death:
        MISL B 4 Bright
        {
            A_Explode(70, 128);
            A_StartSound("weapons/rocklx", CHAN_WEAPON);
            A_Quake(3, 8, 0, 300);
        }
        MISL C 4 Bright;
        MISL D 4 Bright;
        Stop;
    }
}

class GaussSlug : FastProjectile
{
    Default
    {
        Speed 400;
        Radius 2;
        Height 2;
        DamageFunction(250);
        +RIPPER
        +BLOODSPLATTER
        RenderStyle "Add";
        Scale 0.8;
    }

    States
    {
    Spawn:
        PLSS A 1 Bright
        {
            A_SpawnItemEx("SlideSmoke", 0, 0, 0, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        Loop;
    Death:
        PLSE ABCDE 3 Bright;
        Stop;
    }
}

class NapalmGlob : Actor
{
    Default
    {
        Radius 6;
        Height 6;
        Speed 28;
        Damage 15;
        Projectile;
        -NOGRAVITY
        +USEBOUNCESTATE
        BounceType "Doom";
        BounceFactor 0.4;
        WallBounceFactor 0.55;
        Gravity 0.9;
        Scale 0.6;
    }

    States
    {
    Spawn:
        BAL1 AB 2 Bright
        {
            A_SpawnItemEx("SlideSmoke", 0, 0, 0, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        Loop;
    Bounce:
        BAL1 A 0 A_StartSound("weapons/sshoto", CHAN_BODY);
        Goto Spawn;
    Death:
        TNT1 A 0 A_SpawnItemEx("NapalmFireArea", 0, 0, 0, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        Stop;
    }
}

class NapalmFireArea : Actor
{
    int duration;

    Default
    {
        +NOBLOCKMAP
        +NOGRAVITY
        +NOCLIP
        RenderStyle "Add";
        Alpha 0.9;
        Scale 1.4;
    }

    States
    {
    Spawn:
        BAL1 A 0 NoDelay
        {
            duration = 105;
            A_StartSound("weapons/rocklx", CHAN_BODY);
        }
        Goto Active;

    Active:
        // Animate the fire continuously, but apply damage once per six-tic pulse.
        BAL1 CDE 2 Bright;
        TNT1 A 0
        {
            A_Explode(2, 90, XF_NOTMISSILE);
            A_SpawnItemEx("SlideSmoke", random(-28, 28), random(-28, 28), random(0, 36), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
            duration -= 6;
            if (duration <= 0) return ResolveState("Death");
            return ResolveState("Active");
        }

    Death:
        TNT1 A 1;
        Stop;
    }
}

class AirstrikeBeacon : Actor
{
    int ticks;

    Default
    {
        Radius 4;
        Height 4;
        Speed 22;
        Projectile;
        -NOGRAVITY
        +USEBOUNCESTATE
        BounceType "Doom";
        BounceFactor 0.3;
        WallBounceFactor 0.3;
        Gravity 1.0;
        Scale 0.5;
    }

    States
    {
    Spawn:
        MISL A 1 Bright
        {
            A_SpawnItemEx("SlideSmoke", 0, 0, 0, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        Loop;

    Bounce:
        MISL A 0 A_StartSound("weapons/sshoto", CHAN_BODY);
        Goto Spawn;

    Death:
        TNT1 A 0
        {
            ticks = 0;
            Vel = (0, 0, 0);
            bNoGravity = true;
            A_StartSound("weapons/sshotc", CHAN_BODY);
        }
        Goto Countdown;

    Crash:
        TNT1 A 0
        {
            ticks = 0;
            Vel = (0, 0, 0);
            bNoGravity = true;
            A_StartSound("weapons/sshotc", CHAN_BODY);
        }
        Goto Countdown;

    XDeath:
        TNT1 A 0
        {
            ticks = 0;
            Vel = (0, 0, 0);
            bNoGravity = true;
            A_StartSound("weapons/sshotc", CHAN_BODY);
        }
        Goto Countdown;

    Countdown:
        MISL A 5 Bright;
        MISL B 5 Bright
        {
            ticks++;
            A_StartSound("weapons/sshotc", CHAN_BODY);
            if (ticks >= 6) return ResolveState("Explode");
            return ResolveState(null);
        }
        Loop;

    Explode:
        TNT1 A 0
        {
            for (int i = 0; i < 3; i++)
            {
                A_SpawnItemEx("OrbitalBlast", random(-200, 200), random(-200, 200), 0, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
            }
        }
        Stop;
    }
}

class OrbitalBlast : Actor
{
    Default
    {
        +NOBLOCKMAP
        +NOGRAVITY
        +NOCLIP
        RenderStyle "Add";
    }

    States
    {
    Spawn:
        TNT1 A 15;
        TNT1 A 0
        {
            A_Explode(450, 320);
            A_RadiusThrust(900, 320, RTF_NOIMPACTDAMAGE);
            A_Quake(9, 35, 0, 1600);
            A_StartSound("cyber/death", CHAN_BODY);
            for (int i = 0; i < 18; i++)
            {
                A_SpawnItemEx("SlideSmoke", random(-70, 70), random(-70, 70), random(0, 256), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
            }
        }
        BFE1 ABCDEF 4 Bright
        {
            Scale.X = 3.5;
            Scale.Y = 6.0;
        }
        Stop;
    }
}

// ============================================================================
// 2. SISTEMA DE GANCHO Y CADENA 3D
// ============================================================================

class HookChainLink : Actor
{
    Default
    {
        +NOINTERACTION
        +NOGRAVITY
        +FLATSPRITE
        +ROLLCENTER
        RenderStyle "Translucent";
        Alpha 0.8;
        Scale 0.25;
    }

    States
    {
    Spawn:
        CLIP A 1 Bright;
        Loop;
    }
}

class MeatHookProj : FastProjectile
{
    Array<Actor> links;
    const NumLinks = 12;

    Default
    {
        Speed 160;
        Radius 4;
        Height 4;
        Damage 8;
        Projectile;
        +THRUACTORS
    }

    override void PostBeginPlay()
    {
        Super.PostBeginPlay();

        for (int i = 0; i < NumLinks; i++)
        {
            let link = Spawn("HookChainLink", Pos);
            if (link) links.Push(link);
        }
    }

    override void Tick()
    {
        Super.Tick();

        if (!target || isFrozen() || links.Size() == 0) return;

        Vector3 startPos = target.Vec3Offset(0, 0, target.Height * 0.5 - 5);
        Vector3 endPos = Pos;
        Vector3 diff = endPos - startPos;
        double dist = diff.Length();

        if (dist <= 1.0) return;

        Vector3 dir = diff / dist;

        for (int i = 0; i < links.Size(); i++)
        {
            let link = links[i];
            if (!link) continue;

            double t = double(i + 1) / double(links.Size() + 1);
            Vector3 interpPos = startPos + diff * t;
            link.SetOrigin(interpPos, true);
            link.Angle = VectorAngle(dir.X, dir.Y);
            link.Pitch = -asin(dir.Z);
        }
    }

    void DestroyLinks()
    {
        for (int i = 0; i < links.Size(); i++)
        {
            if (links[i]) links[i].Destroy();
        }
        links.Clear();
    }

    override void OnDestroy()
    {
        DestroyLinks();
        Super.OnDestroy();
    }

    States
    {
    Spawn:
        PUFF A 1 Bright;
        Loop;

    Death:
    Crash:
    XDeath:
        PUFF B 0
        {
            DestroyLinks();

            if (target)
            {
                Vector3 dir = (Pos - target.Pos).Unit();
                target.Vel += dir * 45.0;
                target.Vel = (target.Vel.X, target.Vel.Y, target.Vel.Z + 10.0);
                target.A_StartSound("spider/walk", CHAN_BODY);
            }
        }
        PUFF BCD 4 Bright;
        Stop;
    }
}

class GrapplePullProj : FastProjectile
{
    Default
    {
        Speed 100;
        Radius 4;
        Height 4;
        Damage 2;
        Projectile;
    }

    States
    {
    Spawn:
        PUFF A 1 Bright;
        Loop;
    Death:
    Crash:
    XDeath:
        PUFF B 0 A_RadiusThrust(-600, 96, RTF_NOIMPACTDAMAGE);
        PUFF BCD 4 Bright;
        Stop;
    }
}

class FlyingSaw : Actor
{
    Default
    {
        Radius 10;
        Height 10;
        Speed 25;
        Damage 5;
        Projectile;
        +RIPPER
        -NOGRAVITY
        Gravity 0.2;
    }

    States
    {
    Spawn:
        CSAW A 0 A_StartSound("weapons/sawidle", CHAN_WEAPON);
        CSAW AB 2 Bright
        {
            A_Explode(15, 64, XF_NOTMISSILE);
        }
        Loop;
    Death:
        PUFF ABCD 4 Bright;
        Stop;
    }
}

class ChargeBeam : FastProjectile
{
    Default
    {
        Speed 150;
        Radius 2;
        Height 2;
        DamageFunction(random(60, 80));
        +RIPPER
        +BLOODSPLATTER
        RenderStyle "Add";
    }

    States
    {
    Spawn:
        PLSS A 1 Bright;
        Loop;
    Death:
        PLSE ABCDE 3 Bright;
        Stop;
    }
}

class DragonBreathFire : FastProjectile
{
    Default
    {
        Speed 45;
        Radius 6;
        Height 6;
        DamageFunction(random(5, 10));
        +RIPPER
        RenderStyle "Add";
        Alpha 0.9;
        Scale 0.8;
    }

    States
    {
    Spawn:
        BAL1 AB 2 Bright;
        BAL1 A 0 A_Explode(5, 32, XF_NOTMISSILE);
        Loop;
    Death:
        BAL1 CDE 3 Bright;
        Stop;
    }
}

class NukeMissile : Rocket
{
    Default
    {
        Speed 20;
        Damage 100;
        Scale 1.5;
    }

    States
    {
    Spawn:
        MISL A 1 Bright A_StartSound("weapons/rocklf", CHAN_WEAPON);
        Loop;
    Death:
        MISL B 1 Bright
        {
            if (target && target.player)
                target.A_SetBlend(0xFFFFFF, 1.0, 1);
            A_Explode(500, 512);
            A_StartSound("cyber/death", CHAN_BODY);
            A_Quake(8, 25, 0, 1000);
        }
        MISL B 1 Bright
        {
            if (target && target.player)
                target.A_SetBlend(0x080008, 0.90, 1);
        }
        MISL B 8 Bright;
        MISL C 8 Bright;
        MISL D 8 Bright;
        Stop;
    }
}

class GravityOrb : PlasmaBall
{
    Default
    {
        Speed 15;
        Damage 8;
        Scale 1.2;
        RenderStyle "Add";
        Alpha 0.92;
    }

    States
    {
    Spawn:
        PLSS A 2 Bright;
        PLSS B 2 Bright
        {
            A_RadiusThrust(-650, 280, RTF_NOIMPACTDAMAGE);
            A_Explode(4, 112);
            if (random(0, 2) == 0)
                A_SpawnItemEx("TLHEnergySpark", random(-12, 12), random(-12, 12),
                    random(-8, 12), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        Loop;
    Death:
        PLSE A 0 Bright
        {
            A_RadiusThrust(-950, 224, RTF_NOIMPACTDAMAGE);
            A_Quake(4, 10, 0, 320);
            A_StartSound("weapons/bfgf", CHAN_BODY, CHANF_DEFAULT, 0.65);
            A_SpawnItemEx("PlasmaNova", 0, 0, 0, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        PLSE ABCDE 3 Bright;
        Stop;
    }
}

class EMPPlasma : PlasmaBall
{
    Default
    {
        Speed 35;
        Damage 14;
        RenderStyle "Add";
        Alpha 0.95;
        Scale 0.9;
    }

    States
    {
    Spawn:
        PLSS A 3 Bright;
        PLSS B 3 Bright
        {
            A_Explode(3, 72);
            if (random(0, 2) == 0)
                A_SpawnItemEx("TLHEnergySpark", random(-6, 6), random(-6, 6),
                    random(-4, 8), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        Loop;
    Death:
        PLSE A 2 Bright
        {
            A_Explode(65, 144);
            A_RadiusThrust(650, 144, RTF_NOIMPACTDAMAGE);
            A_StartSound("weapons/bfgf", CHAN_WEAPON, CHANF_DEFAULT, 0.55);
            A_Quake(3, 8, 0, 320);
            for (int i = 0; i < 8; i++)
                A_SpawnItemEx("TLHEnergySpark", random(-36, 36), random(-36, 36),
                    random(-8, 30), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        PLSE BCDE 2 Bright;
        Stop;
    }
}


// ============================================================================
// PLASMA IMPACT VFX / ION SPREAD
// ============================================================================
class TLHEnergySpark : Actor
{
    Default
    {
        +NOINTERACTION
        +NOBLOCKMAP
        +NOGRAVITY
        +NOCLIP
        RenderStyle "Add";
        Alpha 0.82;
        Scale 0.30;
    }

    States
    {
    Spawn:
        PLSE A 1 Bright;
        PLSE B 1 Bright;
        PLSE C 2 Bright A_FadeOut(0.28);
        PLSE D 2 Bright A_FadeOut(0.38);
        Stop;
    }
}

class IonPlasmaBolt : PlasmaBall
{
    Default
    {
        Speed 28;
        DamageFunction(random(12, 18));
        Scale 0.72;
        RenderStyle "Add";
    }

    States
    {
    Spawn:
        PLSS AB 1 Bright;
        Loop;
    Death:
        PLSE A 1 Bright
        {
            A_Explode(14, 64);
            A_StartSound("weapons/bfgf", CHAN_BODY, CHANF_DEFAULT, 0.35);
            for (int i = 0; i < 3; i++)
                A_SpawnItemEx("TLHEnergySpark", random(-14, 14), random(-14, 14),
                    random(-6, 18), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        PLSE BCDE 2 Bright;
        Stop;
    }
}

class PlasmaNova : Actor
{
    Default
    {
        +NOINTERACTION
        +NOBLOCKMAP
        +NOGRAVITY
        +NOCLIP
        RenderStyle "Add";
        Alpha 0.92;
        Scale 1.35;
    }

    States
    {
    Spawn:
        TNT1 A 0 NoDelay
        {
            A_Explode(60, 160);
            A_RadiusThrust(-650, 176, RTF_NOIMPACTDAMAGE);
            A_Quake(4, 10, 0, 340);
            A_StartSound("weapons/bfgf", CHAN_BODY, CHANF_DEFAULT, 0.55);
            for (int i = 0; i < 14; i++)
                A_SpawnItemEx("TLHEnergySpark", random(-68, 68), random(-68, 68),
                    random(-8, 44), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        BFE1 ABCDEF 2 Bright;
        Stop;
    }
}

class BFGBeam : FastProjectile
{
    Default
    {
        Speed 200;
        Radius 4;
        Height 4;
        Damage 160;
        +RIPPER
        RenderStyle "Add";
        Scale 0.58;
    }

    States
    {
    Spawn:
        BFS1 A 3 Bright
        {
            A_SpawnItemEx("TLHEnergySpark", random(-3, 3), random(-3, 3),
                random(-3, 3), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        BFS1 B 3 Bright
        {
            A_SpawnItemEx("TLHEnergySpark", random(-3, 3), random(-3, 3),
                random(-3, 3), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        Loop;
    Death:
        BFE1 A 1 Bright
        {
            if (target && target.player)
                target.A_SetBlend(0xFFFFFF, 1.0, 1);
            A_StartSound("weapons/bfgx", CHAN_BODY, CHANF_DEFAULT, 0.80);
            A_Explode(70, 96);
            A_RadiusThrust(360, 96, RTF_NOIMPACTDAMAGE);
            A_Quake(3, 6, 0, 240);
            for (int i = 0; i < 6; i++)
                A_SpawnItemEx("TLHEnergySpark", random(-28, 28), random(-28, 28),
                    random(-8, 24), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        BFE1 B 1 Bright
        {
            if (target && target.player)
                target.A_SetBlend(0x080008, 0.90, 1);
        }
        BFE1 B 1 Bright;
        BFE1 CDEF 2 Bright;
        Stop;
    }
}

// Native Doom II BFG projectile: preserve its original death animation and spray,
// adding a single high-contrast frame only when this powerful shot impacts.
class TLHBFGImpactBall : BFGBall replaces BFGBall
{
    States
    {
    Death:
        BFE1 A 1 Bright
        {
            if (target && target.player)
                target.A_SetBlend(0xFFFFFF, 1.0, 1);
        }
        BFE1 B 1 Bright
        {
            if (target && target.player)
                target.A_SetBlend(0x080008, 0.90, 1);
        }
        BFE1 A 7 Bright;
        BFE1 B 7 Bright;
        BFE1 C 8 Bright A_BFGSpray;
        BFE1 DEF 8 Bright;
        Stop;
    }
}

// El proyectil BFG de Doom es BFGBall, no BFG9000 (que es el arma).
class BFGSlowOrb : BFGBall
{
    Default
    {
        Speed 10;
        Damage 200;
        Scale 1.5;
        RenderStyle "Add";
    }

    States
    {
    Spawn:
        BFS1 A 4 Bright;
        BFS1 B 4 Bright
        {
            A_Explode(6, 96);
            A_RadiusThrust(-700, 192, RTF_NOIMPACTDAMAGE);
            if (random(0, 2) == 0)
                A_SpawnItemEx("TLHEnergySpark", random(-20, 20), random(-20, 20),
                    random(-8, 18), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        Loop;
    Death:
        BFE1 A 1 Bright
        {
            if (target && target.player)
                target.A_SetBlend(0xFFFFFF, 1.0, 1);
            A_Explode(220, 224);
            A_RadiusThrust(-1400, 256, RTF_NOIMPACTDAMAGE);
            A_Quake(8, 24, 0, 800);
            A_StartSound("cyber/death", CHAN_BODY, CHANF_DEFAULT, 0.65);
            for (int i = 0; i < 18; i++)
                A_SpawnItemEx("TLHEnergySpark", random(-84, 84), random(-84, 84),
                    random(-12, 48), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        BFE1 A 1 Bright
        {
            if (target && target.player)
                target.A_SetBlend(0x080008, 0.90, 1);
        }
        BFE1 BCDEF 4 Bright;
        Stop;
    }
}

class M203Grenade : Actor
{
    Default
    {
        Radius 5;
        Height 5;
        Speed 35;
        Damage 20;
        Scale 0.6;
        Projectile;
        -NOGRAVITY
        +USEBOUNCESTATE
        BounceType "Doom";
        BounceFactor 0.45;
        WallBounceFactor 0.55;
        Gravity 0.6;
    }

    States
    {
    Spawn:
        MISL A 1 Bright;
        Loop;
    Bounce:
        MISL A 0 A_StartSound("weapons/sshoto", CHAN_BODY);
        Goto Spawn;
    Death:
        MISL B 6 Bright
        {
            A_Explode(120, 128);
            A_StartSound("weapons/rocklx", CHAN_WEAPON);
            A_Quake(3, 10, 0, 400);
        }
        MISL C 4 Bright;
        MISL D 4 Bright;
        Stop;
    }
}




class TLHTacticalMissile : Rocket
{
    Default
    {
        Speed 28;
        Damage 45;
        Radius 7;
        Height 7;
        Scale 0.45;
        +SEEKERMISSILE
    }
    States
    {
    Spawn:
        MISL A 1 Bright { A_SeekerMissile(8, 18, SMF_LOOK | SMF_PRECISE); }
        Loop;
    Death:
        MISL B 5 Bright
        {
            A_Explode(70, 128);
            A_StartSound("weapons/rocklx", CHAN_WEAPON);
            A_Quake(3, 7, 0, 240);
        }
        MISL C 4 Bright;
        MISL D 4 Bright;
        Stop;
    }
}

// ============================================================================
// 3. ARSENAL TÁCTICO
// ============================================================================

// ============================================================================
// 3B. PROCEDURAL WEAPON PSPRITE ROTATION
// ============================================================================
// The actual PSprite rotation logic lives inside TacticalPlayer so it stays in
// play context. GZDoom does not allow a data-context static Object function to
// call play functions such as GetTLHWeaponMotionWeight().


class DashFist : Fist replaces Fist
{
    Default
    {
        Weapon.SlotNumber 1;
        Weapon.SelectionOrder 100;
        Weapon.Kickback 20;
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        ZUNG A 0
        {
            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
        }
        ZUNG A 1
        {
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;
    Deselect:
        ZUNG A 1 A_Lower;
        Loop;
    Select:
        ZUNG A 1 A_Raise;
        Loop;
    Fire:
        ZUNG B 3;
        ZUNG C 3
        {
            A_CustomPunch(20, TRUE, CPF_PULLIN, "BulletPuff", 64, 0, 0, "ArmorBonus", "weapons/melee");
            A_SetPitch(pitch - 1.0, SPF_INTERPOLATE);
        }
        ZUNG D 4;
        ZUNG C 3;
        ZUNG B 4 A_ReFire;
        Goto Ready;
    AltFire:
        ZUNG B 4
        {
            A_Recoil(-25);
            A_StartSound("skeleton/swing", CHAN_WEAPON);
        }
        ZUNG C 3
        {
            A_CustomPunch(90, TRUE, CPF_PULLIN, "BulletPuff", 80, 0, 0, "ArmorBonus", "weapons/melee");
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            A_Quake(2, 5, 0, 100);
        }
        ZUNG D 8;
        ZUNG C 4;
        ZUNG B 5;
        Goto Ready;
    Zoom:
        ZUNG B 5;
        ZUNG C 5
        {
            A_Explode(80, 128, XF_NOTMISSILE);
            A_StartSound("cyber/hoof", CHAN_BODY);
            A_SetPitch(pitch + 4.0, SPF_INTERPOLATE);
            A_Quake(3, 8, 0, 200);
        }
        ZUNG D 10;
        Goto Ready;
    Reload:
        ZUNG B 2 A_StartSound("vile/sight", CHAN_BODY);
        ZUNG C 8
        {
            A_RadiusThrust(800, 192, RTF_NOIMPACTDAMAGE);
            A_SetPitch(pitch - 2.0, SPF_INTERPOLATE);
        }
        ZUNG D 8;
        Goto Ready;
    }

}

class HookChainsaw : Chainsaw replaces Chainsaw
{
    Default
    {
        Weapon.SlotNumber 1;
        Weapon.SelectionOrder 110;
        Weapon.Kickback 80;
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        SAWG C 0
        {
            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
        }
        SAWG C 1
        {
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;
    Deselect:
        SAWG C 1 A_Lower;
        Loop;
    Select:
        SAWG C 1 A_Raise;
        Loop;
    Fire:
        SAWG A 0 A_StartSound("*xdeath", CHAN_VOICE);
    Hold:
        SAWG A 4
        {
            A_Saw();
            A_Recoil(-4);
            A_SetPitch(pitch - 0.5, SPF_INTERPOLATE);
        }
        SAWG B 4
        {
            A_Saw();
            A_Recoil(-4);
            A_SetPitch(pitch + 0.5, SPF_INTERPOLATE);
        }
        SAWG B 0 A_ReFire;
        Goto Ready;
    AltFire:
        SAWG C 4;
        SAWG C 10
        {
            A_FireProjectile("FlyingSaw");
            A_SetPitch(pitch - 3.0, SPF_INTERPOLATE);
        }
        SAWG C 20;
        Goto Ready;
    Zoom:
        SAWG C 2;
        SAWG C 5
        {
            A_FireProjectile("GrapplePullProj");
            A_StartSound("spider/walk", CHAN_WEAPON);
        }
        SAWG C 10;
        Goto Ready;
    Reload:
        SAWG C 5
        {
            A_DamageSelf(5);
            A_StartSound("weapons/sawup", CHAN_WEAPON);
        }
        SAWG A 1 { A_Saw(); A_Recoil(-6); A_SetPitch(pitch - 1.0, SPF_INTERPOLATE); }
        SAWG B 1 { A_Saw(); A_Recoil(-6); A_SetPitch(pitch + 1.0, SPF_INTERPOLATE); }
        SAWG A 1 { A_Saw(); A_Recoil(-6); A_SetPitch(pitch - 1.0, SPF_INTERPOLATE); }
        SAWG B 1 { A_Saw(); A_Recoil(-6); A_SetPitch(pitch + 1.0, SPF_INTERPOLATE); }
        SAWG C 15;
        Goto Ready;
    Spawn:
        CSAW A -1;
        Stop;
    }

}

class RecoilPistol : Pistol replaces Pistol
{
    bool fullAuto;
    bool dualWield;
    int reloadDecisionTicks;
    bool reloadButtonHeld;
    int dualTapWindow;

    Default
    {
        Weapon.SlotNumber 2;
        Weapon.SelectionOrder 200;
        Weapon.Kickback 80;
        Weapon.AmmoType1 "Clip";
        Weapon.AmmoGive1 20;
        Weapon.AmmoUse1 1;
        Weapon.AmmoType2 "RocketAmmo";
        Weapon.AmmoUse2 1;
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        PISG A 0
        {
            if (invoker.dualWield)
                return ResolveState("ReadyDual");

            A_OverlayScale(PSP_WEAPON, 0.92, 0.92);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
            A_OverlayOffset(PSP_WEAPON, 0, 32);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PISG A 1
        {
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;


    ReadyDual:
        PISG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.90, 0.90);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
            A_OverlayOffset(PSP_WEAPON, -42, 46);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PISG A 1
        {
            double sway = sin(level.time * 0.032 * TLH_RAD_TO_DEG) * 0.45;
            A_OverlayOffset(PSP_WEAPON, -42 + sway, 46 + cos(level.time * 0.027 * TLH_RAD_TO_DEG) * 0.16, 0);
            A_OverlayRotate(PSP_WEAPON, -1.0 + sin(level.time * 0.020 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;

    PistolLeftDraw:
        PISG A 1
        {
            A_OverlayScale(TLH_AKIMBO_LAYER, 0.88, 0.88);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_MIRROR, true);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_PLAYERTRANSLATED, true);
            A_OverlayOffset(TLH_AKIMBO_LAYER, 0, 70);
            A_OverlayRotate(TLH_AKIMBO_LAYER, 5.0);
        }
        PISG A 3 { A_OverlayOffset(TLH_AKIMBO_LAYER, 18, 60, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 3.0); }
        PISG A 3 { A_OverlayOffset(TLH_AKIMBO_LAYER, 34, 51, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 1.0); }
        PISG A 3 { A_OverlayOffset(TLH_AKIMBO_LAYER, 42, 46, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 0); }
        Goto PistolLeftIdle;

    PistolLeftHolster:
        PISG A 2 { A_OverlayOffset(TLH_AKIMBO_LAYER, 24, 58, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 3.0); }
        PISG A 2 { A_OverlayOffset(TLH_AKIMBO_LAYER, 0, 70, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 0); }
        Stop;

    PistolLeftIdle:
        PISG A 1
        {
            A_OverlayScale(TLH_AKIMBO_LAYER, 0.88, 0.88);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_MIRROR, true);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_PLAYERTRANSLATED, true);
            A_OverlayOffset(TLH_AKIMBO_LAYER, 42 + sin(level.time * 0.031 * TLH_RAD_TO_DEG) * 0.55, 46 + cos(level.time * 0.026 * TLH_RAD_TO_DEG) * 0.35, 0);
            A_OverlayRotate(TLH_AKIMBO_LAYER, 1.5 + sin(level.time * 0.021 * TLH_RAD_TO_DEG) * 0.35);
            return ResolveState(null);
        }
        Loop;

    PistolLeftFire:
        PISG B 1;
        PISF A 1 Bright;
        PISG A 1;
        Goto PistolLeftIdle;

    DualPistolFlash:
        PISF A 1 Bright A_Light1;
        Goto LightDone;

    Deselect:
        PISG A 0
        {
            invoker.dualWield = false;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_OverlayAlpha(PSP_WEAPON, 1.0);
            A_Lower();
        }
        Loop;

    Select:
        PISG A 0
        {
            invoker.dualWield = false;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            A_Raise();
        }
        Loop;

    Reload:
        PISG A 0
        {
            // Single R keeps the original mode-toggle behavior.
            // Double R is handled centrally by TacticalPlayer.
            invoker.reloadDecisionTicks = 12;
            invoker.reloadButtonHeld = true;
            return ResolveState("ReloadDecision");
        }

    ReloadDecision:
        PISG A 1
        {
            int buttons = player.cmd.buttons;

            if (!(buttons & BT_RELOAD))
                invoker.reloadButtonHeld = false;

            invoker.reloadDecisionTicks--;

            if (invoker.reloadDecisionTicks <= 0)
            {
                if (invoker.fullAuto)
                    return ResolveState("SetSemi");

                return ResolveState("SetAuto");
            }

            return ResolveState("ReloadDecision");
        }

    SetAuto:
        PISG A 4
        {
            invoker.fullAuto = true;
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Print("PISTOL: FULL AUTO");
        }
        Goto FinishReload;

    SetSemi:
        PISG A 4
        {
            invoker.fullAuto = false;
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
            A_Print("PISTOL: MATCH GRADE");
        }
        Goto FinishReload;

    FinishReload:
        PISG A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        PISG A 2 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;


    DualOnStart:
        PISG A 2 { A_OverlayOffset(PSP_WEAPON, -16, 41, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -1.5); }
        PISG A 3 { A_OverlayOffset(PSP_WEAPON, -32, 50, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -4.5); }
        PISG A 3 { A_OverlayOffset(PSP_WEAPON, -42, 56, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -7.0); }
        PISG A 0
        {
            invoker.dualWield = true;
            A_Overlay(TLH_AKIMBO_LAYER, "PistolLeftDraw");
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Print("PISTOL: DUAL WIELD");
            return ResolveState(null);
        }
        PISG A 3 { A_OverlayOffset(PSP_WEAPON, -42, 46, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, 0); }
        Goto ReadyDual;


    DualOffStart:
        PISG A 3
        {
            A_Overlay(TLH_AKIMBO_LAYER, "PistolLeftHolster");
            A_OverlayOffset(PSP_WEAPON, -24, 53, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -3.5);
        }
        PISG A 3 { A_OverlayOffset(PSP_WEAPON, 0, 62, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -1.0); }
        PISG A 0
        {
            invoker.dualWield = false;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
            A_Print("PISTOL: SINGLE WIELD");
            return ResolveState(null);
        }
        PISG A 3 { A_OverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, 0); }
        Goto Ready;

    Fire:
        PISG A 0
        {
            if (invoker.dualWield)
                return ResolveState("FireDualLeft");

            if (invoker.fullAuto)
                return ResolveState("FireAuto");

            return ResolveState(null);
        }
        PISG A 3;
        PISG B 4
        {
            A_GunFlash();
            A_FirePistol();
            A_SetPitch(pitch - 0.6, SPF_INTERPOLATE);
        }
        PISG C 3 A_WeaponOffset(0, 34, WOF_INTERPOLATE);
        PISG B 3 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    FireAuto:
        PISG B 2
        {
            A_GunFlash();
            A_FirePistol();
            A_SetPitch(pitch - 0.8, SPF_INTERPOLATE);
        }
        PISG C 2 A_WeaponOffset(0, 34, WOF_INTERPOLATE);
        PISG A 0 A_ReFire;
        Goto Ready;

    FireDualLeft:
        PISG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("Clip") < 1)
                return ResolveState("ReadyDual");

            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            let mo = player.mo;
            if (mo)
            {
                double shotAngle = angle + FRandom(-3.0, 3.0);
                double shotPitch = pitch + FRandom(-1.5, 1.5);
                mo.LineAttack(shotAngle, 2048, shotPitch, 7, "Normal", "BulletPuff", 0, null, 0, 0, -22.0);
            }
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_Overlay(TLH_AKIMBO_LAYER, "PistolLeftFire");
            A_SetPitch(pitch - 0.55, SPF_INTERPOLATE);
            A_Recoil(2);
            return ResolveState(null);
        }
        PISG B 2;
        PISG A 0
        {
            if (invoker.fullAuto && (player.cmd.buttons & BT_ATTACK))
                return ResolveState("FireDualLeft");
            return ResolveState("ReadyDual");
        }

    FireDualRight:
        PISG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("Clip") < 1)
                return ResolveState("ReadyDual");

            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            let mo = player.mo;
            if (mo)
            {
                double shotAngle = angle + FRandom(-3.0, 3.0);
                double shotPitch = pitch + FRandom(-1.5, 1.5);
                mo.LineAttack(shotAngle, 2048, shotPitch, 7, "Normal", "BulletPuff", 0, null, 0, 0, 22.0);
            }
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_GunFlash();
            A_SetPitch(pitch - 0.55, SPF_INTERPOLATE);
            A_Recoil(2);
            return ResolveState(null);
        }
        PISG B 2;
        PISG A 0
        {
            if (invoker.fullAuto && (player.cmd.buttons & BT_ALTATTACK))
                return ResolveState("FireDualRight");
            return ResolveState("ReadyDual");
        }

    AltFire:
        PISG A 0
        {
            if (invoker.dualWield)
                return ResolveState("FireDualRight");

            return ResolveState(null);
        }
        PISG A 2 A_StartSound("weapons/sshotl", CHAN_WEAPON);
        PISG A 15;
        PISG B 5
        {
            A_FireProjectile("ChargeBeam");
            A_StartSound("fatbso", CHAN_WEAPON);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            A_Quake(1, 5, 0, 100);
        }
        PISG C 10;
        Goto Ready;

    Zoom:
        PISG A 0
        {
            if ((sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) || player.mo.CountInv("RocketAmmo") >= 1)
                return ResolveState("FireMicroMissile");

            return ResolveState("Ready");
        }
    FireMicroMissile:
        PISG B 5
        {
            A_TakeInventory("RocketAmmo", 1, TIF_NOTAKEINFINITE);
            A_FireProjectile("MicroMissile", useammo: false);
            A_StartSound("weapons/rocklf", CHAN_WEAPON);
            A_SetPitch(pitch - 2.0, SPF_INTERPOLATE);
        }
        PISG C 4;
        PISG B 5;
        Goto Ready;

    Flash:
        PISF A 3 Bright A_Light1;
        PISF B 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        PIST A -1;
        Stop;
    }

}

class OfficerVulkanPistol : Weapon
{
    int weaponMode;
    bool fullAuto;
    bool dualWield;
    int reloadDecisionTicks;
    bool reloadButtonHeld;
    int dualTapWindow;

    Default
    {
        Weapon.SlotNumber 2;
        Weapon.SlotPriority 1.9;
        Weapon.SelectionOrder 190;
        Weapon.Kickback 95;
        Weapon.AmmoType1 "Clip";
        Weapon.AmmoGive1 24;
        Weapon.AmmoUse1 1;
        Weapon.AmmoType2 "RocketAmmo";
        Weapon.AmmoGive2 2;
        Weapon.AmmoUse2 1;
        Inventory.PickupMessage "I found an Officer's Vulkan Pistol!";

        // Procedural recolor embedded in ZScript:
        // red/pink + orange/red accents -> dark neutral gunmetal;
        // existing Doom grays are pushed noticeably darker.
        // PSP_FLASH deliberately does not inherit this mapping.
        // ZScript palette remap, not a tint. Doom's documented player color
        // ramps identify red as 32:47, gray as 96:111 and green as 112:127.
        // Orange/warm ramps are redirected to the same dark gunmetal range.
        Translation
            "32:47=96:111",          // red -> gunmetal gray
            "48:79=88:103",          // warm/orange-brown -> gray
            "80:95=88:103",           // warm neutral -> gray
            "168:175=96:111",         // deep warm -> gray
            "176:191=96:111",         // light red -> gray
            "192:203=96:111",         // remaining colored accents -> gray
            "224:239=96:111";         // final warm/cool accent range -> gray
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        PISG A 0
        {
            if (invoker.dualWield)
                return ResolveState("ReadyDual");

            if (invoker.weaponMode == 1)
                return ResolveState("ReadyLauncher");

            A_OverlayScale(PSP_WEAPON, 0.78, 0.88);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, false);
            A_OverlayOffset(PSP_WEAPON, 0, 32);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PISG A 1
        {
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;


    ReadyDual:
        PISG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.76, 0.86);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, false);
            A_OverlayOffset(PSP_WEAPON, -40, 46);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PISG A 1
        {
            double sway = sin(level.time * 0.032 * TLH_RAD_TO_DEG) * 0.45;
            A_OverlayOffset(PSP_WEAPON, -40 + sway, 46 + cos(level.time * 0.027 * TLH_RAD_TO_DEG) * 0.15, 0);
            A_OverlayRotate(PSP_WEAPON, -1.2 + sin(level.time * 0.020 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;

    OfficerPistolLeftDraw:
        PISG A 1
        {
            A_OverlayScale(TLH_AKIMBO_LAYER, 0.76, 0.86);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_MIRROR, true);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_PLAYERTRANSLATED, true);
            A_OverlayOffset(TLH_AKIMBO_LAYER, 0, 70);
            A_OverlayRotate(TLH_AKIMBO_LAYER, 5.0);
        }
        PISG A 3 { A_OverlayOffset(TLH_AKIMBO_LAYER, 18, 60, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 3.0); }
        PISG A 3 { A_OverlayOffset(TLH_AKIMBO_LAYER, 34, 51, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 1.0); }
        PISG A 3 { A_OverlayOffset(TLH_AKIMBO_LAYER, 40, 46, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 0); }
        Goto OfficerPistolLeftIdle;

    OfficerPistolLeftHolster:
        PISG A 2 { A_OverlayOffset(TLH_AKIMBO_LAYER, 24, 58, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 3.0); }
        PISG A 2 { A_OverlayOffset(TLH_AKIMBO_LAYER, 0, 70, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 0); }
        Stop;

    OfficerPistolLeftIdle:
        PISG A 1
        {
            A_OverlayScale(TLH_AKIMBO_LAYER, 0.76, 0.86);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_MIRROR, true);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_PLAYERTRANSLATED, true);
            A_OverlayOffset(TLH_AKIMBO_LAYER, 40 + sin(level.time * 0.03 * TLH_RAD_TO_DEG) * 0.55, 46 + cos(level.time * 0.025 * TLH_RAD_TO_DEG) * 0.35, 0);
            A_OverlayRotate(TLH_AKIMBO_LAYER, 1.4 + sin(level.time * 0.02 * TLH_RAD_TO_DEG) * 0.30);
            return ResolveState(null);
        }
        Loop;

    OfficerPistolLeftFire:
        PISG B 1;
        PISF A 1 Bright;
        PISG A 1;
        Goto OfficerPistolLeftIdle;

    DualPistolFlash:
        PISF A 1 Bright A_Light1;
        Goto LightDone;

    ReadyLauncher:
        PISG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.68, 0.88);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, false);
        }
        PISG A 1
        {
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;

    Deselect:
        PISG A 0
        {
            invoker.weaponMode = 0;
            invoker.dualWield = false;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_OverlayAlpha(PSP_WEAPON, 1.0);
        }
        PISG A 1 A_Lower;
        Loop;

    Select:
        PISG A 0
        {
            invoker.weaponMode = 0;
            invoker.dualWield = false;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
        }
        PISG A 1 A_Raise;
        Loop;

    Fire:
        PISG A 0
        {
            if (invoker.dualWield)
                return ResolveState("FireDualLeft");

            if (invoker.weaponMode == 1)
                return ResolveState("FireLauncher");

            if (invoker.fullAuto)
                return ResolveState("FireAuto");

            return ResolveState(null);
        }
        PISG A 3;
        PISG B 4
        {
            A_GunFlash();
            A_WeaponOffset(0, 37, WOF_INTERPOLATE);
            A_FireBullets(2.0, 0, 1, 8, "BulletPuff");
            A_SetPitch(pitch - 2.0, SPF_INTERPOLATE);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_Quake(1, 2, 0, 100);
            A_Recoil(1.4);
        }
        PISG C 3 A_WeaponOffset(0, 34, WOF_INTERPOLATE);
        PISG B 3 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    FireAuto:
        PISG B 3
        {
            A_GunFlash();
            A_WeaponOffset(0, 38, WOF_INTERPOLATE);
            A_FireBullets(3.0, 0, 1, 5, "BulletPuff");
            A_SetPitch(pitch - 1.8, SPF_INTERPOLATE);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_Quake(1.8, 3.0, 0, 100);
            A_Recoil(1.8);
        }
        PISG C 2 A_WeaponOffset(0, 34, WOF_INTERPOLATE);
        PISG A 0 A_ReFire;
        Goto Ready;

    FireDualLeft:
        PISG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("Clip") < 1)
                return ResolveState("ReadyDual");

            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            let mo = player.mo;
            if (mo)
            {
                double shotAngle = angle + FRandom(-2.8, 2.8);
                double shotPitch = pitch + FRandom(-1.3, 1.3);
                mo.LineAttack(shotAngle, 2048, shotPitch, 8, "Normal", "BulletPuff", 0, null, 0, 0, -20.0);
            }
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_Overlay(TLH_AKIMBO_LAYER, "OfficerPistolLeftFire");
            A_SetPitch(pitch - 1.8, SPF_INTERPOLATE);
            A_Quake(1.2, 2.0, 0, 80);
            A_Recoil(1.5);
            return ResolveState(null);
        }
        PISG B 2;
        PISG A 0
        {
            if (invoker.fullAuto && (player.cmd.buttons & BT_ATTACK))
                return ResolveState("FireDualLeft");
            return ResolveState("ReadyDual");
        }

    FireDualRight:
        PISG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("Clip") < 1)
                return ResolveState("ReadyDual");

            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            let mo = player.mo;
            if (mo)
            {
                double shotAngle = angle + FRandom(-2.8, 2.8);
                double shotPitch = pitch + FRandom(-1.3, 1.3);
                mo.LineAttack(shotAngle, 2048, shotPitch, 8, "Normal", "BulletPuff", 0, null, 0, 0, 20.0);
            }
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_GunFlash();
            A_SetPitch(pitch - 1.8, SPF_INTERPOLATE);
            A_Quake(1.2, 2.0, 0, 80);
            A_Recoil(1.5);
            return ResolveState(null);
        }
        PISG B 2;
        PISG A 0
        {
            if (invoker.fullAuto && (player.cmd.buttons & BT_ALTATTACK))
                return ResolveState("FireDualRight");
            return ResolveState("ReadyDual");
        }

    FireLauncher:
        PISG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("RocketAmmo") < 1)
                return ResolveState("ReadyLauncher");

            return ResolveState(null);
        }
        PISG B 5
        {
            A_TakeInventory("RocketAmmo", 1, TIF_NOTAKEINFINITE);
            A_FireProjectile("OfficerHeavyGrenade", useammo: false);
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 4.5, SPF_INTERPOLATE);
            A_Quake(3, 5, 0, 200);
            A_Recoil(3.5);
        }
        PISG C 5;
        PISG A 5 A_ReFire;
        Goto ReadyLauncher;

    AltFire:
        PISG A 0
        {
            if (invoker.dualWield)
                return ResolveState("FireDualRight");

            return ResolveState(null);
        }
        PISG A 2;
        PISG B 4
        {
            A_FireProjectile("TrackingMicroMissile");
            A_StartSound("weapons/rocklf", CHAN_WEAPON);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            A_Quake(2, 6, 0, 100);
        }
        PISG C 4;
        Goto Ready;

    Reload:
        PISG A 0
        {
            // Single R keeps the original mode-toggle behavior.
            // Double R is handled centrally by TacticalPlayer.
            invoker.reloadDecisionTicks = 12;
            invoker.reloadButtonHeld = true;
            return ResolveState("ReloadDecision");
        }

    ReloadDecision:
        PISG A 1
        {
            int buttons = player.cmd.buttons;

            if (!(buttons & BT_RELOAD))
                invoker.reloadButtonHeld = false;

            invoker.reloadDecisionTicks--;

            if (invoker.reloadDecisionTicks <= 0)
            {
                if (invoker.fullAuto)
                    return ResolveState("SetSemi");

                return ResolveState("SetAuto");
            }

            return ResolveState("ReloadDecision");
        }

    SetAuto:
        PISG A 4
        {
            invoker.fullAuto = true;
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Print("OFFICER VULKAN: FULL AUTO");
        }
        Goto FinishReload;

    SetSemi:
        PISG A 4
        {
            invoker.fullAuto = false;
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
            A_Print("OFFICER VULKAN: SEMI AUTO");
        }
        Goto FinishReload;

    FinishReload:
        PISG A 2 A_WeaponOffset(0, 42, WOF_INTERPOLATE);
        PISG A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        Goto Ready;


    DualOnStart:
        PISG A 2 { A_OverlayOffset(PSP_WEAPON, -16, 41, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -1.5); }
        PISG A 3 { A_OverlayOffset(PSP_WEAPON, -32, 50, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -4.5); }
        PISG A 3 { A_OverlayOffset(PSP_WEAPON, -40, 56, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -7.0); }
        PISG A 0
        {
            invoker.dualWield = true;
            A_Overlay(TLH_AKIMBO_LAYER, "OfficerPistolLeftDraw");
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Print("OFFICER VULKAN: DUAL WIELD");
            return ResolveState(null);
        }
        PISG A 3 { A_OverlayOffset(PSP_WEAPON, -40, 46, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, 0); }
        Goto ReadyDual;


    DualOffStart:
        PISG A 3
        {
            A_Overlay(TLH_AKIMBO_LAYER, "OfficerPistolLeftHolster");
            A_OverlayOffset(PSP_WEAPON, -24, 53, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -3.5);
        }
        PISG A 3 { A_OverlayOffset(PSP_WEAPON, 0, 62, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -1.0); }
        PISG A 0
        {
            invoker.dualWield = false;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
            A_Print("OFFICER VULKAN: SINGLE WIELD");
            return ResolveState(null);
        }
        PISG A 3 { A_OverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, 0); }
        Goto Ready;

    Zoom:
        PISG A 0
        {
            if (invoker.dualWield)
                return ResolveState("ReadyDual");

            if (invoker.weaponMode == 1)
                return ResolveState("SwitchToPistol");

            return ResolveState("SwitchToLauncher");
        }

    SwitchToLauncher:
        PISG A 0
        {
            let tp = TacticalPlayer(player.mo);
            if (tp && !tp.TryAkimboToggle())
                return ResolveState("Ready");

            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            return ResolveState("SwitchLauncherLower");
        }

    SwitchLauncherLower:
        PISG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 44, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -1.0);
        }
        PISG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 52, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -2.0);
        }
        PISG A 0
        {
            invoker.weaponMode = 1;
            A_OverlayOffset(PSP_WEAPON, 0, 42, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PISG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE);
        }
        Goto ReadyLauncher;

    SwitchToPistol:
        PISG A 0
        {
            let tp = TacticalPlayer(player.mo);
            if (tp && !tp.TryAkimboToggle())
                return ResolveState("ReadyLauncher");

            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            return ResolveState("SwitchPistolLower");
        }

    SwitchPistolLower:
        PISG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 44, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 1.0);
        }
        PISG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 52, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 2.0);
        }
        PISG A 0
        {
            invoker.weaponMode = 0;
            A_OverlayOffset(PSP_WEAPON, 0, 42, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PISG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE);
        }
        Goto Ready;

    Flash:
        PISF A 3 Bright A_Light1;
        PISF B 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        ZIST A -1;
        Stop;
    }

}

class RecoilShotgun : Shotgun replaces Shotgun
{
    bool overdrive;

    Default
    {
        Weapon.SlotNumber 3;
        Weapon.SelectionOrder 300;
        Weapon.Kickback 110;
        Weapon.AmmoType1 "Shell";
        Weapon.AmmoGive1 8;
        Weapon.AmmoUse1 1;
        Weapon.AmmoType2 "Shell";
        Weapon.AmmoUse2 1;
    }

    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        // Three flak grenades are fired per alternate trigger; require the full volley.
        if (fireMode == AltFire)
            return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, 3);
        return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, ammocount);
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        SHTG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.92, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
        }
        SHTG A 1
        {
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;
    Deselect:
        SHTG A 1 A_Lower;
        Loop;
    Select:
        SHTG A 1 A_Raise;
        Loop;
    Reload:
        SHTG A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        SHTG A 2 A_WeaponOffset(0, 42, WOF_INTERPOLATE);
        SHTG A 0
        {
            if (invoker.overdrive) return ResolveState("SetNormal");
            return ResolveState("SetOverdrive");
        }
    SetOverdrive:
        SHTG A 8
        {
            invoker.overdrive = true;
            A_StartSound("weapons/shotgr", CHAN_WEAPON);
            A_Print("SHOTGUN: OVERDRIVE");
        }
        Goto FinishReload;
    SetNormal:
        SHTG A 8
        {
            invoker.overdrive = false;
            A_StartSound("weapons/shotgr", CHAN_WEAPON);
            A_Print("SHOTGUN: STANDARD");
        }
        Goto FinishReload;
    FinishReload:
        SHTG A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        SHTG A 2 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    Fire:
        SHTG A 0
        {
            if (invoker.overdrive) return ResolveState("FireOverdrive");
            return ResolveState(null);
        }
        SHTG A 3;
        SHTG A 7
        {
            A_GunFlash();
            A_WeaponOffset(0, 39, WOF_INTERPOLATE);
            A_FireShotgun();
            A_SetPitch(pitch - 2.0, SPF_INTERPOLATE);
        }
        SHTG BC 5;
        SHTG D 4;
        SHTG CB 5;
        SHTG A 3;
        SHTG A 7 { A_WeaponOffset(0, 34, WOF_INTERPOLATE); A_ReFire(); }
        Goto Ready;

    FireOverdrive:
        SHTG A 0
        {
            if ((sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) || player.mo.CountInv("Shell") >= 4) return ResolveState("DoOverdrive");
            return ResolveState("Ready");
        }
    DoOverdrive:
        SHTG A 3;
        SHTG A 7
        {
            // A_FireBullets ya consume AmmoUse1 (1). Tomamos 3 adicionales
            // para que Overdrive cueste exactamente 4 shells.
            A_TakeInventory("Shell", 3, TIF_NOTAKEINFINITE);
            A_GunFlash();
            A_FireBullets(15.0, 5.0, 28, 5, "BulletPuff");
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 8.0, SPF_INTERPOLATE);
            A_Recoil(5);
            A_Quake(4, 8, 0, 200);
        }
        SHTG BC 6;
        SHTG D 10;
        SHTG CB 6;
        SHTG A 4;
        Goto Ready;

    AltFire:
        SHTG A 3;
        SHTG A 5
        {
            A_FireProjectile("FlakGrenade", -5);
            A_FireProjectile("FlakGrenade", 0);
            A_FireProjectile("FlakGrenade", 5);
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 5.0, SPF_INTERPOLATE);
            A_Quake(2, 6, 0, 200);
        }
        SHTG BC 6;
        SHTG D 8;
        SHTG CB 6;
        SHTG A 4;
        Goto Ready;

    Zoom:
        SHTG A 3;
        SHTG A 5
        {
            A_FireProjectile("ShotgunSlug");
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 5.0, SPF_INTERPOLATE);
            A_Recoil(3);
        }
        SHTG BC 6;
        SHTG D 8;
        SHTG CB 6;
        SHTG A 4;
        Goto Ready;

    Flash:
        SHTF A 3 Bright A_Light1;
        SHTF B 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        SHOT A -1;
        Stop;
    }

}

class FastRecoilSSG : SuperShotgun replaces SuperShotgun
{
    int akimboState;
    bool dragonBreath;

    Default
    {
        Weapon.SlotNumber 3;
        Weapon.SelectionOrder 310;
        Weapon.Kickback 120;
        Weapon.AmmoType1 "Shell";
        Weapon.AmmoGive1 8;
        Weapon.AmmoUse1 0;
        Weapon.AmmoType2 "Clip";
        Weapon.AmmoUse2 0;
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        SHT2 A 0
        {
            if (invoker.akimboState == 1)
                return ResolveState("ReadyAkimbo");

            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            A_OverlayOffset(PSP_WEAPON, 0, 32);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        SHT2 A 1
        {
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;

    ReadyAkimbo:
        PISG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.84, 0.92);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 34 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
            A_Overlay(TLH_AKIMBO_LAYER, "SSGPistolLeftIdle");
            return ResolveState(null);
        }
        PISG A 1
        {
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;

    SSGPistolLeftIdle:
        PISG A 1
        {
            A_OverlayScale(TLH_AKIMBO_LAYER, 0.84, 0.92);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_MIRROR, true);
            A_OverlayOffset(TLH_AKIMBO_LAYER, -45 + sin(level.time * 1.9480565) * 0.50, 66 + cos(level.time * 0.027 * TLH_RAD_TO_DEG) * 0.35, 0);
            A_OverlayRotate(TLH_AKIMBO_LAYER, -1.2 + sin(level.time * 0.021 * TLH_RAD_TO_DEG) * 0.32);
            return ResolveState(null);
        }
        Loop;

    SSGPistolLeftFire:
        PISG B 1;
        PISF A 1 Bright;
        PISG A 1;
        Goto SSGPistolLeftIdle;

    PistolAkimboFlash:
        PISF A 1 Bright A_Light1;
        Goto LightDone;

    Reload:
        SHT2 A 0
        {
            if (invoker.akimboState == 1)
                return ResolveState("ReadyAkimbo");

            if (invoker.dragonBreath)
                return ResolveState("SetBuckshot");

            return ResolveState("SetDragon");
        }
        SHT2 A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        SHT2 A 2 A_WeaponOffset(0, 42, WOF_INTERPOLATE);
        Goto SetDragon;

    SetDragon:
        SHT2 A 8
        {
            invoker.dragonBreath = true;
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Print("SSG: DRAGON'S BREATH");
        }
        Goto FinishReload;

    SetBuckshot:
        SHT2 A 8
        {
            invoker.dragonBreath = false;
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
            A_Print("SSG: BUCKSHOT");
        }
        Goto FinishReload;

    FinishReload:
        SHT2 A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        SHT2 A 2 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    FireAkimbo:
        PISG A 0
        {
            if ((sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) || player.mo.CountInv("Clip") >= 1)
                return ResolveState("DoFireAkimbo");

            return ResolveState("ReadyAkimbo");
        }

    DoFireAkimbo:
        PISG A 3;
        PISG B 4
        {
            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            A_GunFlash("PistolAkimboFlash");
            A_FireBullets(5.6, 0, 1, 5, "BulletPuff", 0);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_Overlay(TLH_AKIMBO_LAYER, "SSGPistolLeftFire");
            A_SetPitch(pitch - 0.6, SPF_INTERPOLATE);
        }
        PISG C 3 A_WeaponOffset(0, 34, WOF_INTERPOLATE);
        PISG A 3 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto ReadyAkimbo;

    Fire:
        SHT2 A 0
        {
            if (invoker.akimboState == 1)
                return ResolveState("FireAkimbo");

            if (invoker.dragonBreath)
                return ResolveState("FireDragon");

            if ((sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) || player.mo.CountInv("Shell") >= 2)
                return ResolveState("DoFireSSG");

            return ResolveState("Ready");
        }

    DoFireSSG:
        SHT2 A 3;
        SHT2 A 7
        {
            A_TakeInventory("Shell", 2, TIF_NOTAKEINFINITE);
            A_GunFlash();
            A_WeaponOffset(0, 41, WOF_INTERPOLATE);
            A_FireBullets(11.2, 7.1, 20, 5, "BulletPuff", 0);
            A_StartSound("weapons/sshotf", CHAN_WEAPON);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            A_Quake(3, 5, 0, 100);
        }
        SHT2 B 3;
        SHT2 C 3 A_CheckReload;
        SHT2 D 3 A_OpenShotgun2;
        SHT2 E 3 A_LoadShotgun2;
        SHT2 F 3 A_LoadShotgun2;
        SHT2 G 3 A_CloseShotgun2;
        SHT2 H 3 A_ReFire;
        Goto Ready;

    FireDragon:
        SHT2 A 0
        {
            if ((sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) || player.mo.CountInv("Shell") >= 2)
                return ResolveState("DoFireDragon");

            return ResolveState("Ready");
        }
    DoFireDragon:
        SHT2 A 3;
        SHT2 A 7
        {
            A_TakeInventory("Shell", 2, TIF_NOTAKEINFINITE);
            for (int i = -6; i <= 6; i++)
            {
                A_FireProjectile("DragonBreathFire", random(-10, 10), false, 0, 0, 0, random(-5, 5));
            }
            A_StartSound("fatbso", CHAN_WEAPON);
            A_SetPitch(pitch - 5.0, SPF_INTERPOLATE);
            A_Quake(3, 5, 0, 100);
        }
        SHT2 B 3;
        SHT2 C 3 A_CheckReload;
        SHT2 D 3 A_OpenShotgun2;
        SHT2 E 3 A_LoadShotgun2;
        SHT2 F 3 A_LoadShotgun2;
        SHT2 G 3 A_CloseShotgun2;
        SHT2 H 3 A_ReFire;
        Goto Ready;

    AltFire:
        SHT2 A 0
        {
            if (invoker.akimboState == 1)
                return ResolveState("ReadyAkimbo");

            return ResolveState(null);
        }
        SHT2 A 2;
        SHT2 A 5
        {
            A_FireProjectile("MeatHookProj");
            A_StartSound("weapons/sshoto", CHAN_WEAPON);
            A_SetPitch(pitch - 1.0, SPF_INTERPOLATE);
        }
        SHT2 A 10;
        Goto Ready;

    Zoom:
        SHT2 A 0
        {
            if (invoker.akimboState == 1)
                return ResolveState("SwitchToSSG");

            return ResolveState("SwitchToAkimbo");
        }

    SwitchToAkimbo:
        SHT2 A 0
        {
            let tp = TacticalPlayer(player.mo);
            if (tp && !tp.TryAkimboToggle())
                return ResolveState("Ready");

            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            return ResolveState("AkimboLower");
        }

    AkimboLower:
        SHT2 A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 44, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -1.0);
        }
        SHT2 A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 52, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -2.0);
        }
        SHT2 A 0
        {
            invoker.akimboState = 1;
            A_Overlay(TLH_AKIMBO_LAYER, "SSGPistolLeftIdle");
            A_Print("SSG: AKIMBO PISTOLS");
            return ResolveState(null);
        }
        PISG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
        }
        Goto ReadyAkimbo;

    SwitchToSSG:
        PISG A 0
        {
            let tp = TacticalPlayer(player.mo);
            if (tp && !tp.TryAkimboToggle())
                return ResolveState("ReadyAkimbo");

            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            return ResolveState("SSGLower");
        }

    SSGLower:
        PISG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 44, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 1.0);
        }
        PISG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 52, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 2.0);
        }
        PISG A 0
        {
            invoker.akimboState = 0;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            return ResolveState(null);
        }
        SHT2 A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
        }
        Goto Ready;

    Deselect:
        SHT2 A 0
        {
            invoker.akimboState = 0;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
        }
        SHT2 A 1 A_Lower;
        Loop;

    Select:
        SHT2 A 0
        {
            invoker.akimboState = 0;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
        }
        SHT2 A 1 A_Raise;
        Loop;

    Flash:
        SHT2 I 4 Bright A_Light1;
        SHT2 J 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        SGN2 A -1;
        Stop;
    }

}

class SemiAutoShotgun : Weapon
{
    bool burstMode;

    Default
    {
        Weapon.SlotNumber 3;
        Weapon.SelectionOrder 305;
        Weapon.Kickback 95;
        Weapon.AmmoType1 "Shell";
        Weapon.AmmoGive1 8;
        Weapon.AmmoUse1 1;
        Weapon.AmmoType2 "Shell";
        Weapon.AmmoUse2 1;
        Inventory.PickupMessage "I found a Blood-Iron Semi-Auto Shotgun!";

        // Palette remap in ZScript. Doom's red/light-red ramps are converted
        // into a controlled dark red, while neutral gray ranges remain intact.
        Translation
            "32:47=32:47",            // red -> dark red ramp
            "176:191=32:47",           // light red -> dark red ramp
            "192:203=32:47";            // warm accent -> dark red
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        ZHTG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.96, 1.32);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, false);
        }
        ZHTG A 1
        {
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;
    Deselect:
        ZHTG A 1 A_Lower;
        Loop;
    Select:
        ZHTG A 1 A_Raise;
        Loop;

    Reload:
        ZHTG A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        ZHTG A 2 A_WeaponOffset(0, 42, WOF_INTERPOLATE);
        ZHTG A 0
        {
            if (invoker.burstMode) return ResolveState("SetSemi");
            return ResolveState("SetBurst");
        }
    SetBurst:
        ZHTG A 8
        {
            invoker.burstMode = true;
            A_StartSound("weapons/shotgr", CHAN_WEAPON);
            A_Print("SEMI-AUTO: BURST FIRE");
        }
        Goto FinishReload;
    SetSemi:
        ZHTG A 8
        {
            invoker.burstMode = false;
            A_StartSound("weapons/shotgr", CHAN_WEAPON);
            A_Print("SEMI-AUTO: STANDARD");
        }
        Goto FinishReload;
    FinishReload:
        ZHTG A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        ZHTG A 2 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    Fire:
        ZHTG A 0
        {
            if (invoker.burstMode) return ResolveState("FireBurst");
            return ResolveState(null);
        }
        ZHTG A 2;
        ZHTG B 3
        {
            A_GunFlash();
            A_FireBullets(7.0, 4.0, 8, 5, "BulletPuff");
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 3.5, SPF_INTERPOLATE);
            A_Recoil(2.5);
            A_Quake(1.4, 3.0, 0, 100);
        }
        ZHTG C 2;
        Goto Ready;

    FireBurst:
        ZHTG A 0
        {
            if ((sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) || player.mo.CountInv("Shell") >= 3) return ResolveState("DoBurst");
            return ResolveState("Ready");
        }
    DoBurst:
        ZHTG B 2
        {
            A_TakeInventory("Shell", 3, TIF_NOTAKEINFINITE);
            A_GunFlash();
            A_FireBullets(8.0, 4.0, 7, 5, "BulletPuff", 0);
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 5.0, SPF_INTERPOLATE);
            A_Recoil(2.5);
        }
        ZHTG B 2
        {
            A_GunFlash();
            A_FireBullets(8.0, 4.0, 7, 5, "BulletPuff", 0);
            A_SetPitch(pitch - 2.0, SPF_INTERPOLATE);
        }
        ZHTG B 2
        {
            A_GunFlash();
            A_FireBullets(8.0, 4.0, 7, 5, "BulletPuff", 0);
            A_SetPitch(pitch - 1.0, SPF_INTERPOLATE);
        }
        ZHTG C 5;
        ZHTG A 5;
        Goto Ready;

    AltFire:
        ZHTG A 2;
        ZHTG B 4
        {
            A_FireProjectile("FlakGrenade");
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 7.0, SPF_INTERPOLATE);
            A_Recoil(5);
            A_Quake(4, 8, 0, 150);
        }
        ZHTG C 3;
        ZHTG B 3;
        ZHTG A 4;
        Goto Ready;

    Zoom:
        ZHTG A 2;
        ZHTG B 3
        {
            A_FireProjectile("ShotgunSlug");
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 7.0, SPF_INTERPOLATE);
            A_Recoil(5);
            A_Quake(4, 8, 0, 150);
        }
        ZHTG C 3;
        ZHTG B 3;
        ZHTG A 4;
        Goto Ready;

    Flash:
        ZHTF A 3 Bright A_Light1;
        ZHTF B 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        // ZSHDA0 is the ground pickup sprite only; HUD states above remain ZHTG.
        ZSHD A -1;
        Stop;
    }

}

// ============================================================================
// VANILLA CHAINGUN FLASH FIX
// Keep the original DOOM II CHGG/CHGF/MGUN sprite families and familiar cadence,
// but explicitly trigger the weapon flash on each shot.
// ============================================================================
class TLHChaingun : DoomWeapon replaces Chaingun
{
    Default
    {
        Weapon.SlotNumber 4;
        Weapon.SlotPriority 4.0;
        Weapon.SelectionOrder 400;
        Weapon.AmmoType1 "Clip";
        Weapon.AmmoUse1 1;
        Weapon.AmmoGive1 20;
        Weapon.Kickback 100;
        AttackSound "weapons/chngun";
    }

    States
    {
    Ready:
        CHGG A 1 A_WeaponReady;
        Loop;

    Deselect:
        CHGG A 1 A_Lower;
        Loop;

    Select:
        CHGG A 1 A_Raise;
        Loop;

    Fire:
        CHGG A 4
        {
            A_GunFlash();
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_FireBullets(5.6, 5.6, 1, 5, "BulletPuff");
        }
        CHGG B 4
        {
            A_GunFlash();
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_FireBullets(5.6, 5.6, 1, 5, "BulletPuff");
        }
        CHGG A 0 A_ReFire;
        Goto Ready;

    Flash:
        CHGF A 3 Bright A_Light1;
        CHGF B 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        MGUN A -1;
        Stop;
    }
}

// ============================================================================
// HEAVY CHAINGUN - clean rebuild
// Independent, conventional DoomWeapon implementation.
// Uses stock DOOM II sprites only. Its identity is sustained, faster suppressive
// fire: higher cadence and damage than the M4A1, with more spread and recoil.
// No procedural weapon-HUD drawing, heat system, or custom Tick().
// ============================================================================

// ============================================================================
// HEAVY CHAINGUN AMMUNITION / VISIBLE IMPACTS
// ============================================================================
class HeavyPiercingRound : FastProjectile
{
    Default
    {
        Speed 220;
        Radius 2;
        Height 2;
        DamageFunction(22);
        Projectile;
        +RIPPER
        +BLOODSPLATTER
        RenderStyle "Add";
        Scale 0.30;
    }

    States
    {
    Spawn:
        PLSS A 1 Bright;
        Loop;
    Death:
        PLSE A 1 Bright
        {
            A_Explode(8, 32);
            for (int i = 0; i < 4; i++)
                A_SpawnItemEx("TLHEnergySpark", random(-10, 10), random(-10, 10),
                    random(-6, 12), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        PLSE BCDE 2 Bright;
        Stop;
    }
}

class HeavyPrecisionSlug : HeavyPiercingRound
{
    Default
    {
        Speed 280;
        DamageFunction(30);
        Scale 0.24;
    }
}

class HeavyChaingun : DoomWeapon
{
    bool overdriveMode;

    Default
    {
        Weapon.SlotNumber 4;
        Weapon.SlotPriority 4.8;
        Weapon.SelectionOrder 410;
        Weapon.AmmoType1 "Clip";
        Weapon.AmmoUse1 1;
        Weapon.AmmoGive1 40;
        Weapon.Kickback 190;
        AttackSound "weapons/chngun";
        Inventory.PickupMessage "Picked up the Heavy Chaingun.";
    }

    States
    {
    Ready:
        CHGG A 0
        {
            A_OverlayScale(PSP_WEAPON, 1.04, 1.08);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
            A_OverlayOffset(PSP_WEAPON, 0, 33);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState("HeavyIdle");
        }
    HeavyIdle:
        CHGG A 1
        {
            double sway = sin(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.42;
            A_OverlayOffset(PSP_WEAPON, sway, 33 + cos(level.time * 0.026 * TLH_RAD_TO_DEG) * 0.16, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.020 * TLH_RAD_TO_DEG) * 0.18);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;

    Deselect:
        CHGG A 0
        {
            // Run the reset exactly once. Never loop back through this zero-tic
            // frame, or A_Lower gets its position reset every tic and weapon
            // switching can softlock with the HCG bobbing vertically.
            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayOffset(PSP_WEAPON, 0, 32);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState("DeselectLower");
        }
    DeselectLower:
        CHGG A 1 A_Lower;
        Loop;

    Select:
        CHGG A 0
        {
            // Initialize the drawn pose once, then let A_Raise finish normally.
            A_OverlayScale(PSP_WEAPON, 1.04, 1.08);
            A_OverlayOffset(PSP_WEAPON, 0, 36);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState("SelectRaise");
        }
    SelectRaise:
        CHGG A 1 A_Raise;
        Loop;

    Fire:
        CHGG A 0
        {
            if (invoker.overdriveMode)
            {
                bool infinite = sv_infiniteammo ||
                    (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
                if (!infinite && (!player.mo || player.mo.CountInv("Clip") < 2))
                    return ResolveState("Ready");
                return ResolveState("FireOverdrive");
            }
            return ResolveState("FireSuppression");
        }
    FireSuppression:
        CHGG A 2
        {
            A_GunFlash();
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_FireBullets(7.2, 7.2, 1, 6, "BulletPuff");
            A_SetPitch(pitch - 0.12, SPF_INTERPOLATE);
        }
        CHGG B 2
        {
            // Do not restart the flash here: let CHGF A and CHGF B both render.
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_FireBullets(7.2, 7.2, 1, 6, "BulletPuff");
            A_SetPitch(pitch - 0.12, SPF_INTERPOLATE);
        }
        CHGG A 0 A_ReFire;
        Goto Ready;

    FireOverdrive:
        CHGG A 4
        {
            A_GunFlash();
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite)
                A_TakeInventory("Clip", 2, TIF_NOTAKEINFINITE);
            A_FireProjectile("HeavyPiercingRound", random(-0.7, 0.7), false);
            A_SetPitch(pitch - 0.85, SPF_INTERPOLATE);
            A_Quake(1, 3, 0, 120);
            A_OverlayOffset(PSP_WEAPON, 0, 40);
        }
        CHGG B 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 44);
            A_Quake(2, 5, 0, 180);
        }
        CHGG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 33);
        }
        CHGG A 0 A_ReFire;
        Goto Ready;

    AltFire:
        CHGG A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (infinite || (player.mo && player.mo.CountInv("Clip") >= 6))
                return ResolveState("BreachBurst");
            return ResolveState("Ready");
        }
    BreachBurst:
        CHGG A 4 A_StartSound("weapons/sshotc", CHAN_WEAPON);
        CHGG B 2
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            A_GunFlash();
            if (!infinite)
                A_TakeInventory("Clip", 6, TIF_NOTAKEINFINITE);
            A_FireProjectile("HeavyPiercingRound", -5.0, false);
            A_FireProjectile("HeavyPiercingRound", 0.0, false);
            A_FireProjectile("HeavyPiercingRound", 5.0, false);
            A_SetPitch(pitch - 2.0, SPF_INTERPOLATE);
            A_Quake(4, 10, 0, 320);
            A_OverlayOffset(PSP_WEAPON, 0, 43);
        }
        CHGG B 4
        {
            A_OverlayOffset(PSP_WEAPON, 0, 46);
            A_Quake(2, 5, 0, 220);
        }
        CHGG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 33);
        }
        CHGG A 9;
        Goto Ready;

    Zoom:
        CHGG A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (infinite || (player.mo && player.mo.CountInv("Clip") >= 5))
                return ResolveState("PrecisionBurst");
            return ResolveState("Ready");
        }
    PrecisionBurst:
        CHGG A 4 A_StartSound("weapons/sshotc", CHAN_WEAPON);
        CHGG B 3
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            A_GunFlash();
            if (!infinite)
                A_TakeInventory("Clip", 5, TIF_NOTAKEINFINITE);
            A_FireProjectile("HeavyPrecisionSlug", -0.7, false);
            A_FireProjectile("HeavyPrecisionSlug", 0.0, false);
            A_FireProjectile("HeavyPrecisionSlug", 0.7, false);
            A_SetPitch(pitch - 2.8, SPF_INTERPOLATE);
            A_Quake(3, 8, 0, 280);
            A_OverlayOffset(PSP_WEAPON, 0, 43);
        }
        CHGG B 4
        {
            A_OverlayOffset(PSP_WEAPON, 0, 46);
            A_Quake(2, 5, 0, 220);
        }
        CHGG A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 33);
        }
        CHGG A 10;
        Goto Ready;

    Reload:
        CHGG A 0
        {
            invoker.overdriveMode = !invoker.overdriveMode;
            if (invoker.overdriveMode)
            {
                A_StartSound("weapons/sshotc", CHAN_WEAPON);
                A_Print("HEAVY CHAINGUN: ARMOR-PIERCING OVERDRIVE");
                A_Quake(2, 5, 0, 180);
            }
            else
            {
                A_StartSound("weapons/sshotl", CHAN_WEAPON);
                A_Print("HEAVY CHAINGUN: SUPPRESSION MODE");
            }
            return ResolveState(null);
        }
        CHGG A 7;
        Goto Ready;

    Flash:
        CHGF A 3 Bright A_Light1;
        CHGF B 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        MGUN A -1;
        Stop;
    }
}

class TacticalM4A1 : DoomWeapon
{
    bool burstMode;
    bool dualWield;
    int reloadDecisionTicks;
    bool reloadButtonHeld;
    int dualTapWindow;

    Default
    {
        Weapon.SlotNumber 4;
        Weapon.SelectionOrder 400;
        Weapon.Kickback 90;
        Weapon.AmmoType1 "Clip";
        Weapon.AmmoGive1 40;
        Weapon.AmmoUse1 1;
        Weapon.AmmoType2 "RocketAmmo";
        Weapon.AmmoUse2 1;
        Weapon.AmmoGive2 4;
        AttackSound "weapons/chngun";
    }

    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        // Three-round burst needs a full three-round reserve. Akimbo fires single shots.
        if (fireMode == PrimaryFire && !dualWield && burstMode)
            return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, 3);
        return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, ammocount);
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        ZHGG A 0
        {
            if (invoker.dualWield)
                return ResolveState("ReadyDual");

            A_OverlayScale(PSP_WEAPON, 0.98, 0.98);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
            A_OverlayOffset(PSP_WEAPON, 0, 32);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        ZHGG A 1
        {
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;


    ReadyDual:
        ZHGG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.92, 1.02);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
            A_OverlayOffset(PSP_WEAPON, -30, 46);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        ZHGG A 1
        {
            double sway = sin(level.time * 0.032 * TLH_RAD_TO_DEG) * 0.45;
            A_OverlayOffset(PSP_WEAPON, -30 + sway, 46 + cos(level.time * 0.027 * TLH_RAD_TO_DEG) * 0.18, 0);
            A_OverlayRotate(PSP_WEAPON, -1.0 + sin(level.time * 0.020 * TLH_RAD_TO_DEG) * 0.28);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;

    M4LeftDraw:
        ZHGG A 1
        {
            A_OverlayScale(TLH_AKIMBO_LAYER, 0.92, 1.02);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_MIRROR, true);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_PLAYERTRANSLATED, true);
            A_OverlayOffset(TLH_AKIMBO_LAYER, 0, 70);
            A_OverlayRotate(TLH_AKIMBO_LAYER, 5.0);
        }
        ZHGG A 3 { A_OverlayOffset(TLH_AKIMBO_LAYER, 18, 60, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 3.0); }
        ZHGG A 3 { A_OverlayOffset(TLH_AKIMBO_LAYER, 34, 51, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 1.0); }
        ZHGG A 3 { A_OverlayOffset(TLH_AKIMBO_LAYER, 30, 46, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 0); }
        Goto M4LeftIdle;

    M4LeftHolster:
        ZHGG A 2 { A_OverlayOffset(TLH_AKIMBO_LAYER, 24, 58, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 3.0); }
        ZHGG A 2 { A_OverlayOffset(TLH_AKIMBO_LAYER, 0, 70, WOF_INTERPOLATE); A_OverlayRotate(TLH_AKIMBO_LAYER, 0); }
        Stop;

    M4LeftIdle:
        ZHGG A 1
        {
            A_OverlayScale(TLH_AKIMBO_LAYER, 0.92, 1.02);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_MIRROR, true);
            A_OverlayFlags(TLH_AKIMBO_LAYER, PSPF_PLAYERTRANSLATED, true);
            A_OverlayOffset(TLH_AKIMBO_LAYER, 30 + sin(level.time * 0.03 * TLH_RAD_TO_DEG) * 0.48, 46 + cos(level.time * 0.025 * TLH_RAD_TO_DEG) * 0.36, 0);
            A_OverlayRotate(TLH_AKIMBO_LAYER, 1.0 + sin(level.time * 0.019 * TLH_RAD_TO_DEG) * 0.28);
            return ResolveState(null);
        }
        Loop;

    M4LeftFire:
        ZHGG B 1;
        ZHGG A 1;
        Goto M4LeftIdle;
    Deselect:
        ZHGG A 0
        {
            invoker.dualWield = false;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            A_OverlayRotate(PSP_WEAPON, 0);
        }
        ZHGG A 1 A_Lower;
        Loop;
    Select:
        ZHGG A 0
        {
            invoker.dualWield = false;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
        }
        ZHGG A 1 A_Raise;
        Loop;

    Reload:
        ZHGG A 0
        {
            // Single R keeps the original mode-toggle behavior.
            // Double R is handled centrally by TacticalPlayer.
            invoker.reloadDecisionTicks = 10;
            invoker.reloadButtonHeld = true;
            return ResolveState("ReloadDecision");
        }

    ReloadDecision:
        ZHGG A 1
        {
            int buttons = player.cmd.buttons;

            if (!(buttons & BT_RELOAD))
                invoker.reloadButtonHeld = false;

            invoker.reloadDecisionTicks--;

            if (invoker.reloadDecisionTicks <= 0)
            {
                if (invoker.burstMode)
                    return ResolveState("SetAuto");

                return ResolveState("SetBurst");
            }

            return ResolveState("ReloadDecision");
        }

    SetAuto:
        ZHGG A 8
        {
            invoker.burstMode = false;
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
            A_Print("M4A1: FULL AUTO");
        }
        Goto FinishReload;
    SetBurst:
        ZHGG A 8
        {
            invoker.burstMode = true;
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Print("M4A1: 3-ROUND BURST");
        }
        Goto FinishReload;

    FinishReload:
        ZHGG A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        ZHGG A 2 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    Fire:
        // M4A1 retains its custom ZHGG weapon sprite family.
        // Controlled full-auto cadence of 3 tics per shot (~700 RPM at 35 tics/sec).
        // This is actual gameplay cadence, not only visual animation.
        ZHGG A 0
        {
            if (invoker.dualWield)
                return ResolveState("FireDualLeft");
            if (invoker.burstMode)
                return ResolveState("FireBurst");
            return ResolveState(null);
        }
        ZHGG A 2
        {
            A_FireBullets(5.625, 0, 1, 5, "BulletPuff");
            A_SetPitch(pitch - 0.8, SPF_INTERPOLATE);
        }
        ZHGG B 1;
        ZHGG A 0 A_ReFire;
        Goto Ready;

    FireBurst:
        // Three-round burst. Each shot keeps the same readable A0/B0 animation.
        ZHGG A 2
        {
            A_FireBullets(5.625, 0, 1, 5, "BulletPuff");
            A_SetPitch(pitch - 1.2, SPF_INTERPOLATE);
        }
        ZHGG B 1;
        ZHGG A 2
        {
            A_FireBullets(5.625, 0, 1, 5, "BulletPuff");
            A_SetPitch(pitch - 1.2, SPF_INTERPOLATE);
        }
        ZHGG B 1;
        ZHGG A 2
        {
            A_FireBullets(5.625, 0, 1, 5, "BulletPuff");
            A_SetPitch(pitch - 1.2, SPF_INTERPOLATE);
        }
        ZHGG B 1;
        ZHGG A 15;
        Goto Ready;

    AltFire:
        ZHGG A 0
        {
            // In dual-wield mode M2 belongs to the right-hand weapon.
            if (invoker.dualWield)
                return ResolveState("FireDualRight");

            // The M203 shares RocketAmmo with the rocket launcher.
            if ((sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) ||
                player.mo.CountInv("RocketAmmo") >= 1)
                return ResolveState("FireM203");

            return ResolveState("Ready");
        }
    FireM203:
        ZHGG A 0
        {
            // Consume exactly one grenade round here; don't let the generic
            // projectile action consume the primary M4A1 magazine instead.
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (!infinite)
            {
                if (!player.mo || player.mo.CountInv("RocketAmmo") < 1)
                    return ResolveState("Ready");

                A_TakeInventory("RocketAmmo", 1);
            }

            A_FireProjectile("M203Grenade", useammo: false);
            A_StartSound("weapons/rocklf", CHAN_WEAPON);
            A_SetPitch(pitch - 3.0, SPF_INTERPOLATE);
            A_Recoil(2);
            return ResolveState(null);
        }
        ZHGG B 10;
        ZHGG A 15 A_StartSound("weapons/sshotl", CHAN_WEAPON);
        Goto Ready;

    FireDualLeft:
        ZHGG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("Clip") < 1)
                return ResolveState("ReadyDual");

            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            let mo = player.mo;
            if (mo)
            {
                double shotAngle = angle + FRandom(-5.625, 5.625);
                double shotPitch = pitch + FRandom(-2.1, 2.1);
                mo.LineAttack(shotAngle, 2048, shotPitch, 5, "Normal", "BulletPuff", 0, null, 0, 0, -28.0);
            }
            A_Overlay(TLH_AKIMBO_LAYER, "M4LeftFire");
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_SetPitch(pitch - 0.85, SPF_INTERPOLATE);
            A_Recoil(2.0);
            return ResolveState(null);
        }
        ZHGG B 1;
        ZHGG A 1;
        ZHGG A 0
        {
            if (player.cmd.buttons & BT_ATTACK)
                return ResolveState("FireDualLeft");
            return ResolveState("ReadyDual");
        }

    FireDualRight:
        ZHGG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("Clip") < 1)
                return ResolveState("ReadyDual");

            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            let mo = player.mo;
            if (mo)
            {
                double shotAngle = angle + FRandom(-5.625, 5.625);
                double shotPitch = pitch + FRandom(-2.1, 2.1);
                mo.LineAttack(shotAngle, 2048, shotPitch, 5, "Normal", "BulletPuff", 0, null, 0, 0, 28.0);
            }
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_SetPitch(pitch - 0.85, SPF_INTERPOLATE);
            A_Recoil(2.0);
            return ResolveState(null);
        }
        ZHGG B 1;
        ZHGG A 1;
        ZHGG A 0
        {
            if (player.cmd.buttons & BT_ALTATTACK)
                return ResolveState("FireDualRight");
            return ResolveState("ReadyDual");
        }


    DualOnStart:
        ZHGG A 2 { A_OverlayOffset(PSP_WEAPON, -16, 41, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -1.5); }
        ZHGG A 3 { A_OverlayOffset(PSP_WEAPON, -32, 50, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -4.5); }
        ZHGG A 3 { A_OverlayOffset(PSP_WEAPON, -30, 56, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -7.0); }
        ZHGG A 0
        {
            invoker.dualWield = true;
            A_Overlay(TLH_AKIMBO_LAYER, "M4LeftDraw");
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Print("M4A1: DUAL WIELD ACTIVE | M1 LEFT / M2 RIGHT");
            return ResolveState(null);
        }
        ZHGG A 3 { A_OverlayOffset(PSP_WEAPON, -30, 46, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, 0); }
        Goto ReadyDual;


    DualOffStart:
        ZHGG A 3
        {
            A_Overlay(TLH_AKIMBO_LAYER, "M4LeftHolster");
            A_OverlayOffset(PSP_WEAPON, -24, 53, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -3.5);
        }
        ZHGG A 3 { A_OverlayOffset(PSP_WEAPON, 0, 62, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, -1.0); }
        ZHGG A 0
        {
            invoker.dualWield = false;
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
            A_Print("M4A1: SINGLE WIELD");
            return ResolveState(null);
        }
        ZHGG A 3 { A_OverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE); A_OverlayRotate(PSP_WEAPON, 0); }
        Goto Ready;

    Zoom:
        ZHGG A 1 A_WeaponOffset(-15, 45, WOF_INTERPOLATE);
        ZHGG A 1 A_WeaponOffset(-32, 65, WOF_INTERPOLATE);
        ZHGG A 1 A_WeaponOffset(-45, 85, WOF_INTERPOLATE);
        ZHGG A 2
        {
            // A rifle butt strike should be a short, single-target melee hit.
            A_CustomPunch(20, TRUE, 0, "BulletPuff", 48, 0, 0, "ArmorBonus", "weapons/melee");
            A_SetPitch(pitch + 1.0, SPF_INTERPOLATE);
        }
        ZHGG A 2 A_WeaponOffset(0, 80, WOF_INTERPOLATE);
        ZHGG A 2 A_WeaponOffset(0, 50, WOF_INTERPOLATE);
        ZHGG A 2 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    // Short, immediately visible muzzle flash.
    // Keep it shorter than the full-auto firing cycle so every shot can refresh it.
    Spawn:
        ZGUN A -1;
        Stop;
    }

}

class M60MachineGun : DoomWeapon
{
    bool precisionMode;
    bool braced;
    int stability;

    Default
    {
        Weapon.SlotNumber 4;
        Weapon.SelectionOrder 415;
        Weapon.Kickback 70;
        Weapon.AmmoType1 "Clip";
        Weapon.AmmoGive1 50;
        Weapon.AmmoUse1 1;
        Weapon.AmmoType2 "RocketAmmo";
        Weapon.AmmoUse2 1;

        AttackSound "weapons/chngun";

        Inventory.PickupMessage "I found an M60 Machine Gun!";
    }

    override void Tick()
    {
        Super.Tick();

        if (!Owner || !Owner.player)
            return;

        if (stability < 100)
        {
            if (Owner.player.ReadyWeapon == self && (Owner.player.cmd.buttons & BT_ATTACK))
            {
                stability += 1;
            }
            else
            {
                stability += 3;
            }
        }

        if (stability > 100)
            stability = 100;
    }

    double CurrentSpread()
    {
        double spread;

        if (precisionMode)
            spread = 1.15;
        else
            spread = 2.75;

        if (braced)
            spread *= 0.58;

        spread += (100.0 - double(stability)) * 0.012;

        return spread;
    }

    int CurrentDamage()
    {
        if (precisionMode)
            return 15;

        return 12;
    }

    double CurrentRecoil()
    {
        if (braced)
            return 0.45;

        if (precisionMode)
            return 0.85;

        return 1.10;
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        MSYA A 0
        {
            if (invoker.stability <= 0)
                invoker.stability = 100;

            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, false);
            A_OverlayRenderStyle(PSP_WEAPON, STYLE_Normal);
            A_OverlayAlpha(PSP_WEAPON, 1.0);
        }

        MSYA A 1
        {
            double swayScale = invoker.braced ? 0.35 : 1.0;
            double movement = invoker.braced ? 0.10 : 0.28;

            A_OverlayOffset(
                PSP_WEAPON,
                sin(level.time * 0.031 * TLH_RAD_TO_DEG) * movement * swayScale,
                32.0 + cos(level.time * 0.024 * TLH_RAD_TO_DEG) * 0.10 * swayScale,
                0
            );

            A_OverlayRotate(
                PSP_WEAPON,
                sin(level.time * 0.02 * TLH_RAD_TO_DEG) * 0.18 * swayScale
            );

            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;

    Deselect:
        MSYA A 1
        {
            A_OverlayRenderStyle(PSP_WEAPON, STYLE_Normal);
            A_OverlayAlpha(PSP_WEAPON, 1.0);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_Lower();
        }
        Loop;

    Select:
        MSYA A 1
        {
            invoker.stability = 100;
            A_OverlayRenderStyle(PSP_WEAPON, STYLE_Normal);
            A_OverlayAlpha(PSP_WEAPON, 1.0);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_Raise();
        }
        Loop;

    Reload:
        MSYA A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        MSYA A 2 A_WeaponOffset(0, 41, WOF_INTERPOLATE);
        MSYA A 0
        {
            if (invoker.precisionMode)
                return ResolveState("SetSustain");

            return ResolveState("SetPrecision");
        }

    SetPrecision:
        MSYA A 7
        {
            invoker.precisionMode = true;
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Print("M60: PRECISION FIRE");
        }
        MSYA A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        MSYA A 2 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    SetSustain:
        MSYA A 7
        {
            invoker.precisionMode = false;
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
            A_Print("M60: SUSTAINED FIRE");
        }
        MSYA A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        MSYA A 2 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    Fire:
        MSYA A 0
        {
            if (invoker.precisionMode)
                return ResolveState("FirePrecision");

            return ResolveState("FireSustain");
        }

    FireSustain:
        MSYA A 1
        {
            int dmg = invoker.CurrentDamage();
            double spread = invoker.CurrentSpread();
            double recoil = invoker.CurrentRecoil();

            A_FireBullets(spread, spread * 0.38, 1, dmg, "BulletPuff");
            if ((int(level.time) % 3) == 0)
                A_StartSound("weapons/chngun", CHAN_WEAPON, CHANF_DEFAULT, 0.80);

            invoker.stability -= invoker.braced ? 1 : 2;
            if (invoker.stability < 45)
                invoker.stability = 45;

            A_WeaponOffset(0, 39.5, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, invoker.braced ? 0.0 : 0.7, 39.5, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -recoil);
            A_SetPitch(pitch - (invoker.braced ? 0.18 : 0.42), SPF_INTERPOLATE);
        }
        MSYB A 1;
        MSYA A 2
        {
            A_WeaponOffset(0, 34.0, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, 0.0, 33.0, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, invoker.braced ? 0.10 : 0.22);
        }
        MSYA A 0 A_ReFire;
        Goto Ready;

    FirePrecision:
        MSYA A 1
        {
            int dmg = invoker.CurrentDamage();
            double spread = invoker.CurrentSpread();
            double recoil = invoker.CurrentRecoil();

            A_FireBullets(spread, spread * 0.28, 1, dmg, "BulletPuff");
            if ((int(level.time) % 3) == 0)
                A_StartSound("weapons/chngun", CHAN_WEAPON, CHANF_DEFAULT, 0.80);

            invoker.stability -= invoker.braced ? 1 : 2;
            if (invoker.stability < 55)
                invoker.stability = 55;

            A_WeaponOffset(0, invoker.braced ? 38.5 : 40.0, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, invoker.braced ? 0.0 : 0.5, invoker.braced ? 38.5 : 40.0, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -recoil);
            A_SetPitch(pitch - (invoker.braced ? 0.14 : 0.32), SPF_INTERPOLATE);
        }
        MSYB A 1;
        MSYA A 3
        {
            A_WeaponOffset(0, 34.0, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, 0.0, 33.0, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, invoker.braced ? 0.08 : 0.18);
        }
        MSYA A 0 A_ReFire;
        Goto Ready;

    AltFire:
        MSYA A 1;
        MSYB A 1
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("RocketAmmo") < 1)
                return ResolveState("Ready");

            A_FireProjectile("M203Grenade");
            A_StartSound("weapons/rocklf", CHAN_WEAPON);
            A_WeaponOffset(0, 39, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, 0, 38, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -1.0);
            A_SetPitch(pitch - 2.0, SPF_INTERPOLATE);
            A_Recoil(2);
            return ResolveState(null);
        }
        MSYA A 3;
        MSYA A 4 A_WeaponOffset(0, 34, WOF_INTERPOLATE);
        MSYA A 2 A_OverlayOffset(PSP_WEAPON, 0, 32, WOF_INTERPOLATE);
        Goto Ready;

    Zoom:
        MSYA A 0
        {
            let tp = TacticalPlayer(player.mo);
            if (tp && !tp.TryModeToggle())
                return ResolveState("Ready");

            if (invoker.braced)
            {
                A_StartSound("weapons/sshoto", CHAN_WEAPON);
                return ResolveState("UnbraceStart");
            }

            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            return ResolveState("BraceStart");
        }

    BraceStart:
        MSYA A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 42, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -0.8);
        }
        MSYA A 3
        {
            invoker.braced = true;
            A_OverlayOffset(PSP_WEAPON, 0, 45, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_Print("M60: BRACED / LOW RECOIL");
        }
        MSYA A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE);
        }
        Goto Ready;

    UnbraceStart:
        MSYA A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 43, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0.8);
        }
        MSYA A 3
        {
            invoker.braced = false;
            A_OverlayOffset(PSP_WEAPON, 0, 40, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_Print("M60: BRACE DISENGAGED");
        }
        MSYA A 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE);
        }
        Goto Ready;

    Spawn:
        MSIX A -1;
        Stop;
    }

}

// Legacy alias kept for old map references.


class RecoilRocketLauncher : RocketLauncher replaces RocketLauncher
{
    bool nukeMode;

    Default
    {
        Weapon.SlotNumber 5;
        Weapon.SelectionOrder 500;
        Weapon.Kickback 120;
        Weapon.AmmoType1 "RocketAmmo";
        Weapon.AmmoGive1 4;
        Weapon.AmmoUse1 1;
        Weapon.AmmoType2 "RocketAmmo";
        Weapon.AmmoUse2 1;
    }

    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        // Require all three rockets before starting a micro-missile volley.
        if (fireMode == AltFire)
            return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, 3);
        return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, ammocount);
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        RISG A 0
        {
            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
        }
        RISG A 1
        {
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;
    Deselect:
        RISG A 1 A_Lower;
        Loop;
    Select:
        RISG A 1 A_Raise;
        Loop;

    Reload:
        RISG A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        RISG A 2 A_WeaponOffset(0, 42, WOF_INTERPOLATE);
        RISG A 0
        {
            if (invoker.nukeMode) return ResolveState("SetNormal");
            return ResolveState("SetNuke");
        }
    SetNuke:
        RISG A 8
        {
            invoker.nukeMode = true;
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Print("ROCKET: TACTICAL NUKE LOADED");
        }
        Goto FinishReload;
    SetNormal:
        RISG A 8
        {
            invoker.nukeMode = false;
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
            A_Print("ROCKET: STANDARD PAYLOAD");
        }
        Goto FinishReload;
    FinishReload:
        RISG A 2 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        RISG A 2 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    Fire:
        RISG A 0
        {
            if (invoker.nukeMode) return ResolveState("FireNuke");
            return ResolveState(null);
        }
        RISG B 8
        {
            A_GunFlash();
            A_FireMissile();
            A_SetPitch(pitch - 3.0, SPF_INTERPOLATE);
        }
        RISG B 12;
        RISG A 0 A_ReFire;
        Goto Ready;

    FireNuke:
        RISG A 0
        {
            if ((sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) || player.mo.CountInv("RocketAmmo") >= 10) return ResolveState("DoFireNuke");
            return ResolveState("Ready");
        }
    DoFireNuke:
        RISG B 10
        {
            A_TakeInventory("RocketAmmo", 10, TIF_NOTAKEINFINITE);
            A_FireProjectile("NukeMissile", useammo: false);
            A_SetPitch(pitch - 10.0, SPF_INTERPOLATE);
            A_Recoil(8);
            A_Quake(3, 8, 0, 200);
            A_StartSound("weapons/rocklf", CHAN_WEAPON);
        }
        RISG B 20;
        Goto Ready;

    AltFire:
        RISG B 2
        {
            A_FireProjectile("MicroMissile");
            A_SetPitch(pitch - 1.0, SPF_INTERPOLATE);
        }
        RISG B 2
        {
            A_FireProjectile("MicroMissile");
            A_SetPitch(pitch - 1.0, SPF_INTERPOLATE);
        }
        RISG B 2
        {
            A_FireProjectile("MicroMissile");
            A_SetPitch(pitch - 1.0, SPF_INTERPOLATE);
        }
        RISG B 15;
        Goto Ready;

    // Emergency melee: strike with the launcher body. It does not magically fire pistol ammo.
    Zoom:
        RISG A 3 A_WeaponOffset(0, 36, WOF_INTERPOLATE);
        RISG B 4
        {
            A_CustomPunch(20, TRUE, 0, "BulletPuff", 48, 0, 0, "ArmorBonus", "weapons/melee");
            A_SetPitch(pitch - 1.2, SPF_INTERPOLATE);
        }
        RISG A 7 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    Flash:
        RISF A 3 Bright A_Light1;
        RISF B 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        ZAUN A -1;
        Stop;
    }

}

// Obsolete placeholder launcher classes removed. Their old MAPINFO DoomEdNums must also be removed.

class RecoilPlasmaRifle : PlasmaRifle replaces PlasmaRifle
{
    bool empMode;

    Default
    {
        Weapon.SlotNumber 6;
        Weapon.SelectionOrder 600;
        Weapon.Kickback 45;
        Weapon.AmmoType1 "Cell";
        Weapon.AmmoGive1 30;
        Weapon.AmmoUse1 1;
        Weapon.AmmoType2 "Cell";
        Weapon.AmmoUse2 5;
    }

    States
    {
    Ready:
        PISG A 0;
    TLHPickupReadyShim:
        PLSG A 0
        {
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            A_OverlayOffset(PSP_WEAPON, 0, 32);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PLSG A 1
        {
            double sway = sin(level.time * 1.9480565) * 0.30;
            A_OverlayOffset(PSP_WEAPON, sway, 32 + cos(level.time * 0.027 * TLH_RAD_TO_DEG) * 0.13, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.021 * TLH_RAD_TO_DEG) * 0.28);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;
    Deselect:
        PLSG A 0
        {
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            A_OverlayRotate(PSP_WEAPON, 0);
        }
        PLSG A 1 A_Lower;
        Loop;
    Select:
        PLSG A 0
        {
            A_ClearOverlays(TLH_AKIMBO_LAYER, TLH_AKIMBO_LAYER);
            A_OverlayRotate(PSP_WEAPON, 0);
        }
        PLSG A 1 A_Raise;
        Loop;

    Reload:
        PLSG A 0
        {
            invoker.empMode = !invoker.empMode;
            if (invoker.empMode)
            {
                A_StartSound("weapons/sshotc", CHAN_WEAPON);
                A_Print("PLASMA RIFLE: EMP FIELD ENABLED");
            }
            else
            {
                A_StartSound("weapons/sshotl", CHAN_WEAPON);
                A_Print("PLASMA RIFLE: STANDARD PLASMA");
            }
            return ResolveState(null);
        }
        PLSG A 8;
        Goto Ready;

    Fire:
        PLSG A 0
        {
            if (invoker.empMode)
                return ResolveState("FireEMP");
            return ResolveState(null);
        }
        PLSG A 2
        {
            A_WeaponOffset(0, 35, WOF_INTERPOLATE);
            A_FirePlasma();
            A_SetPitch(pitch - 0.3, SPF_INTERPOLATE);
        }
        PLSG B 1 A_ReFire;
        Goto Ready;

    FireEMP:
        PLSG A 5
        {
            A_GunFlash();
            A_FireProjectile("EMPPlasma");
            A_SetPitch(pitch - 1.8, SPF_INTERPOLATE);
            A_Quake(2, 5, 0, 180);
            A_OverlayOffset(PSP_WEAPON, 0, 37);
        }
        PLSG B 3
        {
            A_OverlayOffset(PSP_WEAPON, 0, 40);
        }
        PLSG B 4
        {
            A_OverlayOffset(PSP_WEAPON, 0, 32);
            A_ReFire();
        }
        PLSG B 13;
        Goto Ready;

    AltFire:
        PLSG A 4 A_StartSound("weapons/sshotc", CHAN_WEAPON);
        PLSG B 4
        {
            A_FireProjectile("GravityOrb");
            A_SetPitch(pitch - 3.5, SPF_INTERPOLATE);
            A_Quake(3, 7, 0, 240);
            A_OverlayOffset(PSP_WEAPON, 0, 37);
        }
        PLSG B 4
        {
            A_OverlayOffset(PSP_WEAPON, 0, 41);
        }
        PLSG B 5
        {
            A_OverlayOffset(PSP_WEAPON, 0, 32);
            A_ReFire();
        }
        Goto Ready;

    Zoom:
        PLSG A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && (!player.mo || player.mo.CountInv("Cell") < 9))
                return ResolveState("Ready");
            return ResolveState("PlasmaSpread");
        }
    PlasmaSpread:
        PLSG A 4 A_StartSound("weapons/sshoto", CHAN_WEAPON);
        PLSG B 3 Bright
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite)
                A_TakeInventory("Cell", 9, TIF_NOTAKEINFINITE);
            for (int i = -4; i <= 4; i++)
                A_FireProjectile("IonPlasmaBolt", i * 4.0, false);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            A_Quake(3, 8, 0, 280);
            A_OverlayOffset(PSP_WEAPON, 0, 40);
        }
        PLSG B 4
        {
            A_OverlayOffset(PSP_WEAPON, 0, 43);
        }
        PLSG B 5
        {
            A_OverlayOffset(PSP_WEAPON, 0, 32);
        }
        PLSG B 9 A_ReFire;
        Goto Ready;

    Flash:
        PLSF A 2 Bright A_Light1;
        PLSF B 2 Bright A_Light2;
        Goto LightDone;
    Spawn:
        PLAS A -1;
        Stop;
    }
}

class RecoilBFG9000 : BFG9000 replaces BFG9000
{
    Default
    {
        Weapon.SlotNumber 7;
        Weapon.SelectionOrder 700;
        Weapon.Kickback 160;
        Weapon.AmmoType1 "Cell";
        Weapon.AmmoGive1 40;
        Weapon.AmmoUse1 40;
        Weapon.AmmoType2 "Cell";
        Weapon.AmmoUse2 10;
    }

    States
    {
    Ready:
        PISG A 0;
    TLHPickupReadyShim:
        ZFGG A 0
        {
            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
        }
        ZFGG A 1
        {
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35,
                32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;
    Deselect:
        ZFGG A 1 A_Lower;
        Loop;
    Select:
        ZFGG A 1 A_Raise;
        Loop;

    Fire:
        ZFGG A 12 A_BFGSound;
        ZFGG B 4 A_GunFlash;
        ZFGG B 3
        {
            A_FireBFG();
            A_SetPitch(pitch - 7.0, SPF_INTERPOLATE);
            A_Quake(7, 20, 0, 600);
            A_OverlayOffset(PSP_WEAPON, 0, 45);
        }
        ZFGG B 4
        {
            A_OverlayOffset(PSP_WEAPON, 0, 47);
        }
        ZFGG B 4
        {
            A_OverlayOffset(PSP_WEAPON, 0, 32);
        }
        ZFGG B 16 A_ReFire;
        Goto Ready;

    AltFire:
        ZFGG A 0
        {
            if ((sv_infiniteammo || (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true))) ||
                (player.mo && player.mo.CountInv("Cell") >= 10))
                return ResolveState("DoBFGBurst");
            return ResolveState("Ready");
        }
    DoBFGBurst:
        ZFGG A 6 A_BFGSound;
        ZFGG B 1
        {
            if (!(sv_infiniteammo || (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true))))
                A_TakeInventory("Cell", 10, TIF_NOTAKEINFINITE);
            A_Explode(90, 176, XF_EXPLICITDAMAGETYPE, false, 176);
            if (player && player.mo)
                player.mo.A_SetBlend(0xFFFFFF, 1.0, 1);
            A_RadiusThrust(900, 176, RTF_NOIMPACTDAMAGE);
            A_Recoil(8);
            A_SetPitch(pitch - 5.0, SPF_INTERPOLATE);
            A_Quake(6, 18, 0, 520);
            A_OverlayOffset(PSP_WEAPON, 0, 44);
            for (int i = 0; i < 12; i++)
                A_SpawnItemEx("TLHEnergySpark", random(-72, 72), random(-72, 72),
                    random(-8, 40), 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        }
        ZFGG B 1
        {
            if (player && player.mo)
                player.mo.A_SetBlend(0x080008, 0.90, 1);
        }
        ZFGG B 2;
        ZFGG B 4
        {
            A_OverlayOffset(PSP_WEAPON, 0, 48);
            A_Quake(3, 8, 0, 280);
        }
        ZFGG B 4
        {
            A_OverlayOffset(PSP_WEAPON, 0, 32);
        }
        ZFGG B 10;
        Goto Ready;

    Zoom:
        ZFGG A 0
        {
            if ((sv_infiniteammo || (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true))) ||
                (player.mo && player.mo.CountInv("Cell") >= 10))
                return ResolveState("DoBFGBeam");
            return ResolveState("Ready");
        }
    DoBFGBeam:
        ZFGG A 8 A_BFGSound;
        ZFGG B 4
        {
            if (!(sv_infiniteammo || (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true))))
                A_TakeInventory("Cell", 10, TIF_NOTAKEINFINITE);
            A_FireProjectile("BFGBeam", useammo: false);
            A_SetPitch(pitch - 5.0, SPF_INTERPOLATE);
            A_Quake(5, 14, 0, 480);
            A_OverlayOffset(PSP_WEAPON, 0, 43);
        }
        ZFGG B 4
        {
            A_OverlayOffset(PSP_WEAPON, 0, 47);
        }
        ZFGG B 4
        {
            A_OverlayOffset(PSP_WEAPON, 0, 32);
        }
        ZFGG B 8;
        Goto Ready;

    Reload:
        ZFGG A 0
        {
            if ((sv_infiniteammo || (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true))) ||
                (player.mo && player.mo.CountInv("Cell") >= 10))
                return ResolveState("DoSlowOrb");
            return ResolveState("Ready");
        }
    DoSlowOrb:
        ZFGG A 20 A_BFGSound;
        ZFGG B 4 A_GunFlash;
        ZFGG B 4
        {
            if (!(sv_infiniteammo || (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true))))
                A_TakeInventory("Cell", 10, TIF_NOTAKEINFINITE);
            A_FireProjectile("BFGSlowOrb", useammo: false);
            A_SetPitch(pitch - 10.0, SPF_INTERPOLATE);
            A_Recoil(7);
            A_Quake(5, 14, 0, 620);
            A_OverlayOffset(PSP_WEAPON, 0, 44);
        }
        ZFGG B 5
        {
            A_OverlayOffset(PSP_WEAPON, 0, 48);
        }
        ZFGG B 5
        {
            A_OverlayOffset(PSP_WEAPON, 0, 32);
        }
        ZFGG B 25;
        Goto Ready;

    Flash:
        ZFGF A 11 Bright A_Light1;
        ZFGF B 6 Bright A_Light2;
        Goto LightDone;
    Spawn:
        BFUG A -1;
        Stop;
    }
}

// ============================================================================
// 4. ARMAS EXPERIMENTALES
// ============================================================================

class AMR99RailRifle : Weapon
{
    bool isZoomed;

    Default
    {
        Weapon.SlotNumber 8;
        Weapon.SelectionOrder 800;
        Weapon.Kickback 140;
        Weapon.AmmoType1 "Cell";
        Weapon.AmmoGive1 20;
        Weapon.AmmoUse1 10;
        Inventory.PickupMessage "I found an AMR-99 Gauss Rifle!";

        // Palette remap in ZScript. Doom green is 112:127. The Plasma Rifle source
        // uses that ramp, so it is redirected to Doom's light-blue family.
        // Black/gray ramps are lifted to cleaner, lighter gunmetal values.
        Translation
            "0:31=88:103",            // black/dark -> light gunmetal
            "32:47=96:111",           // red -> gray
            "48:79=88:103",           // brown/warm -> light gunmetal
            "80:95=96:111",           // dark neutral -> gray
            "96:111=88:103",          // gray -> lighter gray
            "112:127=192:207",        // Doom green -> electric blue family
            "128:191=88:103",         // remaining warm/cool -> light gunmetal
            "192:255=96:111";         // rest -> neutral gray
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        ZLSG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.84, 0.92);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, false);
        }
        ZLSG A 1
        {
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;
    Deselect:
        ZLSG A 0
        {
            invoker.isZoomed = false;
            A_ZoomFactor(1.0, ZOOM_INSTANT);
        }
        ZLSG A 1 A_Lower;
        Loop;
    Select:
        ZLSG A 1 A_Raise;
        Loop;

    Fire:
        ZLSG A 4;
        ZLSG B 6
        {
            A_GunFlash();
            A_WeaponOffset(0, 46, WOF_INTERPOLATE);
            A_FireProjectile("GaussSlug");
            A_StartSound("weapons/railgf", CHAN_WEAPON);
            A_SetPitch(pitch - 7.0, SPF_INTERPOLATE);
            A_Quake(7, 14, 0, 350);
            A_Recoil(5);
        }
        ZLSG B 28;
        ZLSG A 8;
        Goto Ready;

    Reload:
        ZLSG A 0
        {
            if (invoker.isZoomed)
            {
                invoker.isZoomed = false;
                A_ZoomFactor(1.0, ZOOM_INSTANT);
            }
            A_StartSound("weapons/sshoto", CHAN_WEAPON);
        }
        ZLSG A 8;
        Goto Ready;

    Zoom:
        ZLSG A 0
        {
            if (invoker.isZoomed) return ResolveState("ZoomOut");
            return ResolveState("ZoomIn");
        }
    ZoomIn:
        ZLSG A 4
        {
            invoker.isZoomed = true;
            A_StartSound("weapons/sshoto", CHAN_WEAPON);
            A_ZoomFactor(3.0, ZOOM_INSTANT);
        }
        Goto Ready;
    ZoomOut:
        ZLSG A 4
        {
            invoker.isZoomed = false;
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_ZoomFactor(1.0, ZOOM_INSTANT);
        }
        Goto Ready;

    Flash:
        ZLSF A 3 Bright A_Light1;
        ZLSF B 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        ZLAS A -1;
        Stop;
    }

}

class HellfireProjector : Weapon
{
    Default
    {
        Weapon.SlotNumber 9;
        Weapon.SelectionOrder 900;
        Weapon.Kickback 80;
        Weapon.AmmoType1 "RocketAmmo";
        Weapon.AmmoGive1 4;
        Weapon.AmmoUse1 1;
        Inventory.PickupMessage "I found a Hellfire Napalm Projector!";

        // Use the unmodified vanilla DOOM II Rocket Launcher sprites (MISG/MISF).
        // Keep the custom firing mechanics, but do not recolor or shrink the stock art.

    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        MISG A 0
        {
            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, false);
        }
        MISG A 1
        {
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;
    Deselect:
        MISG A 1 A_Lower;
        Loop;
    Select:
        MISG A 1 A_Raise;
        Loop;

    Fire:
        MISG A 3;
        MISG B 5
        {
            A_GunFlash();
            A_WeaponOffset(0, 36, WOF_INTERPOLATE);
            A_FireProjectile("NapalmGlob");
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 2.5, SPF_INTERPOLATE);
            A_Quake(3, 8, 0, 220);
        }
        MISG B 5;
        MISG A 3 A_ReFire;
        Goto Ready;

    AltFire:
        MISG A 3;
        MISG B 5
        {
            A_FireProjectile("NapalmGlob", random(-4, 4), true, 0, 0, 0, random(-2, 2));
            A_StartSound("weapons/rocklf", CHAN_WEAPON);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            A_Quake(2, 5, 0, 160);
        }
        MISG B 5;
        Goto Ready;

    Flash:
        MISF A 2 Bright A_Light1;
        MISF B 2 Bright A_Light2;
        Goto LightDone;

    Spawn:
        LAUN A -1;
        Stop;
    }

}

class AirstrikeDesignator : Weapon
{
    Default
    {
        Weapon.SlotNumber 0;
        Weapon.SelectionOrder 50;
        Weapon.Kickback 20;
        Weapon.AmmoType1 "RocketAmmo";
        Weapon.AmmoGive1 5;
        Weapon.AmmoUse1 5;
        Inventory.PickupMessage "I found an Orbital Strike Beacon!";

        // Palette remap in ZScript. This is a true flare treatment: most of
        // the design is moved into red ramps, while black remains dark enough
        // to preserve the object's silhouette and readability.
        Translation
            "0:31=32:47",              // black/dark -> dark red
            "32:47=32:47",             // red -> dark red
            "48:95=176:191",           // body/warm colors -> flare red
            "96:111=176:191",          // gray -> flare red
            "112:127=176:191",         // green -> flare red
            "128:175=176:191",         // remaining warm colors -> red
            "176:255=176:191";         // bright colors -> flare red
        Scale 0.56;
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        ZISG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.54, 0.54);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, false);
        }
        ZISG A 1
        {
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, sin(level.time * 0.035 * TLH_RAD_TO_DEG) * 0.35, 32 + cos(level.time * 0.028 * TLH_RAD_TO_DEG) * 0.12, 0);
            A_OverlayRotate(PSP_WEAPON, sin(level.time * 0.023 * TLH_RAD_TO_DEG) * 0.30);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;
    Deselect:
        ZISG A 1 A_Lower;
        Loop;
    Select:
        ZISG A 1 A_Raise;
        Loop;

    Fire:
        ZISG A 8;
        ZISG B 12
        {
            A_FireProjectile("AirstrikeBeacon");
            A_StartSound("weapons/rocklf", CHAN_WEAPON);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            A_Print("ORBITAL BEACON DEPLOYED! Seek cover immediately!");
        }
        ZISG A 40;
        Goto Ready;

    Flash:
        ZISF A 3 Bright A_Light1;
        ZISF B 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        ZIST A -1;
        Stop;
    }

}

// ============================================================================
// 5. JUGADOR / MOVIMIENTO TÁCTICO
// ============================================================================


// ============================================================================
// NEW WEAPONS WITH VANILLA SPRITES ONLY
// These classes reuse IWAD art. Their gameplay and motion make them distinct;
// the WAD does not need any new sprite lumps.
// ============================================================================

// Custom Service Revolver.
// GZDoom requires a four-character sprite prefix. All frames use RVOL:
// RVOLQ0 (idle), RVOLA0/RVOLB0/RVOLC0 (fire frames), RVOLG0 (world pickup).
class ServiceRevolver : Weapon
{
    // Six-shot cylinder. Clip ammo is held in reserve and transferred on reload.
    int cylinderAmmo;
    bool cylinderInitialized;
    bool triggerLatched;
    bool altTriggerLatched;
    bool reloadLatched;

    Default
    {
        Weapon.SlotNumber 2;
        Weapon.SlotPriority 2.05;
        Weapon.SelectionOrder 205;
        Weapon.Kickback 105;
        Weapon.AmmoType1 "Clip";
        // Grant 12 rounds: up to six go into the cylinder on first equip,
        // leaving the remainder as reserve ammunition.
        Weapon.AmmoGive1 12;
        Weapon.AmmoUse1 0;
        Weapon.AmmoType2 "Clip";
        Weapon.AmmoUse2 0;
        Inventory.PickupMessage "Picked up the .357 Service Revolver.";
    }

    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        // The chambered cylinder is custom state; AmmoUse1 is zero so the
        // engine's default weapon-ammo test alone cannot represent it.
        bool infinite = sv_infiniteammo ||
            (Owner && Owner.FindInventory("PowerInfiniteAmmo", true));

        if (infinite || cylinderAmmo > 0)
            return true;

        // An empty cylinder with reserve rounds is reloadable, not dry.
        // Keep the weapon selected so the player can press R to top it up.
        if (Owner && Owner.CountInv("Clip") > 0)
            return true;

        // Both cylinder and reserve are empty. Do not call PickNewWeapon()
        // from CheckAmmo(): this runs inside the weapon firing path and can
        // interrupt the active PSprite state transition, leaving the weapon
        // stuck between Ready/Deselect and causing procedural motion jitter.
        // Keep the empty revolver selected; the player can switch normally.
        // (autoSwitch is intentionally ignored for this custom-cylinder weapon.)
        return false;
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        RVOL Q 0
        {
            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
        }
        RVOL Q 1
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (!invoker.cylinderInitialized)
            {
                invoker.cylinderInitialized = true;
                if (infinite)
                {
                    invoker.cylinderAmmo = 6;
                }
                else if (player.mo)
                {
                    int reserve = player.mo.CountInv("Clip");
                    invoker.cylinderAmmo = min(6, reserve);
                    if (invoker.cylinderAmmo > 0)
                        A_TakeInventory("Clip", invoker.cylinderAmmo, TIF_NOTAKEINFINITE);
                }
            }

            // A revolver fires once per trigger press. Holding the trigger cannot
            // turn the weapon into a slow automatic rifle.
            if (!(player.cmd.buttons & BT_ATTACK))
                invoker.triggerLatched = false;
            if (!(player.cmd.buttons & BT_RELOAD))
                invoker.reloadLatched = false;
            if (!(player.cmd.buttons & BT_ALTATTACK))
                invoker.altTriggerLatched = false;

            int readyFlags = WRF_NoBob;
            if (!invoker.reloadLatched)
                readyFlags |= WRF_ALLOWRELOAD;
            if (invoker.triggerLatched || invoker.altTriggerLatched)
                readyFlags |= WRF_NOPRIMARY | WRF_NOSECONDARY;

            // Primitive look sway: subtle and smoothed by TacticalPlayer's
            // existing look-inertia variables. WRF_NoBob keeps A_WeaponReady
            // from overwriting these offsets immediately afterward.
            let tp = TacticalPlayer(player.mo);
            double swayX = tp ? clamp(tp.tlhAnimLookX * 1.25, -1.8, 1.8) : 0.0;
            double swayY = tp ? clamp(-tp.tlhAnimLookY * 0.85, -1.2, 1.2) : 0.0;

            // Classic DOOM II movement bob is combined into this single offset.
            // Do not layer BobWeapon() over the revolver's custom action offsets.
            double bobSpeed = clamp(player.GetWBobSpeed(), 0.45, 2.40);
            double bobPhase = tp ? tp.tlhAnimStepPhase :
                double(level.time) * 6.0 * bobSpeed;
            double bobStrength = sqrt(max(player.bob, 0.0)) * 1.10;
            double classicBobX = sin(bobPhase) * bobStrength;
            double classicBobY = sin(bobPhase * 2.0) * bobStrength * 0.38;
            A_OverlayOffset(PSP_WEAPON, swayX + classicBobX,
                32.0 + swayY + classicBobY, WOF_INTERPOLATE);
            A_WeaponReady(readyFlags);
        }
        Loop;

    Deselect:
        RVOL Q 1 A_Lower;
        Loop;

    Select:
        RVOL Q 1 A_Raise;
        Loop;

    // Reload like a speed-loader cylinder: top up to six rounds from shared Clip reserve.
    // The original sprite set has no separate open-cylinder frames, so the reload is
    // represented by a short lowered/tilted weapon motion rather than invented artwork.
    Reload:
        RVOL Q 0
        {
            invoker.reloadLatched = true;
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (!infinite && invoker.cylinderAmmo >= 6)
            {
                A_Print("REVOLVER: CYLINDER FULL");
                return ResolveState("Ready");
            }
            if (!infinite && (!player.mo || player.mo.CountInv("Clip") <= 0))
            {
                A_StartSound("weapons/sshoto", CHAN_WEAPON);
                A_Print("REVOLVER: NO RESERVE AMMO");
                return ResolveState("Ready");
            }

            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            return ResolveState(null);
        }
        RVOL Q 5
        {            A_OverlayOffset(PSP_WEAPON, 2, 39, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -4.0);
        }
        RVOL Q 8
        {            A_OverlayOffset(PSP_WEAPON, 4, 43, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -9.0);
        }
        RVOL Q 10
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (infinite)
            {
                invoker.cylinderAmmo = 6;
            }
            else if (player.mo)
            {
                int reserve = player.mo.CountInv("Clip");
                int needed = 6 - invoker.cylinderAmmo;
                int loaded = min(needed, reserve);
                if (loaded > 0)
                {
                    A_TakeInventory("Clip", loaded, TIF_NOTAKEINFINITE);
                    invoker.cylinderAmmo += loaded;
                }
            }
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
        }
        RVOL Q 7
        {            A_OverlayOffset(PSP_WEAPON, 1, 36, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -3.0);
        }
        RVOL Q 5
        {            A_OverlayOffset(PSP_WEAPON, 0, 32, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_Print(String.Format("REVOLVER: %d/6", invoker.cylinderAmmo));
        }
        Goto Ready;

    // Single-action trigger: high per-shot impact, narrow spread, deliberate recovery.
    Fire:
        RVOL A 0
        {
            invoker.triggerLatched = true;
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (!infinite && invoker.cylinderAmmo <= 0)
            {
                A_StartSound("weapons/sshoto", CHAN_WEAPON);
                A_Print("REVOLVER: CYLINDER EMPTY | PRESS R");
                return ResolveState("Ready");
            }
            return ResolveState(null);
        }
        RVOL A 2;
        RVOL B 1
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (!infinite)
                invoker.cylinderAmmo--;

            // Flags 0 prevent the engine from spending the shared reserve a second time.
            A_FireBullets(0.18, 0.12, 1, 8, "BulletPuff", 0);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 3.6, SPF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, 0, 39, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -3.0);

            if (!infinite && invoker.cylinderAmmo == 1)
                A_Print("REVOLVER: LAST ROUND");
            else if (!infinite && invoker.cylinderAmmo == 0)
                A_Print("REVOLVER: CYLINDER EMPTY | PRESS R");
        }
        RVOL C 2
        {            A_OverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -1.0);
        }
        RVOL Q 4
        {            A_OverlayOffset(PSP_WEAPON, 0, 32, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
        }
        Goto Ready;

    // Fan the Hammer: three fast, progressively less accurate shots. It uses
    // three loaded rounds, is triggered once per click, and cannot be spammed by holding M2.
    AltFire:
        RVOL Q 0
        {
            invoker.altTriggerLatched = true;
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (!infinite && invoker.cylinderAmmo < 3)
            {
                A_StartSound("weapons/sshoto", CHAN_WEAPON);
                A_Print(String.Format("REVOLVER: FAN NEEDS 3 ROUNDS (%d/6) | PRESS R", invoker.cylinderAmmo));
                return ResolveState("Ready");
            }
            return ResolveState("FanFire1");
        }
    FanFire1:
        // M4A1-style burst rhythm: show the pre-shot A frame for one tic,
        // then the B firing frame; repeat for each cartridge.
        RVOL A 1
        {            A_OverlayOffset(PSP_WEAPON, 0, 32, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
        }
        RVOL B 1
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && invoker.cylinderAmmo > 0) invoker.cylinderAmmo--;
            A_FireBullets(0.7, 0.3, 1, 4, "BulletPuff", 0);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 0.8, SPF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, 0, 38, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -2.4);
        }
        RVOL A 1
        {            A_OverlayOffset(PSP_WEAPON, 0, 33, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -0.8);
        }
        RVOL B 1
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && invoker.cylinderAmmo > 0) invoker.cylinderAmmo--;
            A_FireBullets(1.8, 0.7, 1, 4, "BulletPuff", 0);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 1.0, SPF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, 0, 39, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -3.0);
        }
        RVOL A 1
        {            A_OverlayOffset(PSP_WEAPON, 0, 34, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -1.0);
        }
        RVOL B 1
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && invoker.cylinderAmmo > 0) invoker.cylinderAmmo--;
            A_FireBullets(3.0, 1.0, 1, 4, "BulletPuff", 0);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 1.4, SPF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, 0, 41, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -3.8);
            if (!infinite && invoker.cylinderAmmo <= 0)
                A_Print("REVOLVER: CYLINDER EMPTY | PRESS R");
        }
        RVOL C 3
        {            A_OverlayOffset(PSP_WEAPON, 0, 36, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -1.3);
        }
        RVOL Q 4
        {            A_OverlayOffset(PSP_WEAPON, 0, 32, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
        }
        Goto Ready;

    Spawn:
        RVOL G -1;
        Stop;
    }
}

class StreetSweeperShotgun : Weapon
{
    Default
    {
        Weapon.SlotNumber 3;
        Weapon.SlotPriority 3.25;
        Weapon.SelectionOrder 325;
        Weapon.Kickback 125;
        Weapon.AmmoType1 "Shell";
        Weapon.AmmoGive1 16;
        Weapon.AmmoUse1 1;
        Weapon.AmmoType2 "Shell";
        Weapon.AmmoUse2 2;
        Inventory.PickupMessage "Picked up the Street Sweeper Shotgun.";
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        SHTG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.96, 1.02);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
        }
        SHTG A 1 A_WeaponReady(WRF_ALLOWRELOAD);
        Loop;

    Deselect:
        SHTG A 1 A_Lower;
        Loop;

    Select:
        SHTG A 1
        {
            A_OverlayScale(PSP_WEAPON, 0.96, 1.02);
            A_Raise();
        }
        Loop;

    Fire:
        SHTG B 0 A_GunFlash;
        SHTG B 5
        {
            A_FireBullets(7.0, 5.5, 8, 4, "BulletPuff");
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 2.3, SPF_INTERPOLATE);
            A_Recoil(5.5);
        }
        SHTG C 3 A_ReFire;
        Goto Ready;

    AltFire:
        SHTG B 0 A_GunFlash;
        SHTG B 8
        {
            A_FireBullets(4.5, 3.5, 14, 4, "BulletPuff");
            A_StartSound("weapons/sshotf", CHAN_WEAPON);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            A_Recoil(8.0);
        }
        SHTG C 5;
        Goto Ready;

    Flash:
        SHTF A 3 Bright A_Light1;
        SHTF B 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        SHOT A -1;
        Stop;
    }
}







class TacticalPlayer : DoomPlayer replaces DoomPlayer
{
    int jumpCount;
    int slideCooldown;
    int fallTicks;
    int akimboCooldown;
    double maximumFallSpeed;
    bool isSlamming;
    bool wasOnGround;
    bool akimboButtonHeld;

    // Player-corpse smell reaction, owned by the active player pawn.
    Actor tlhCorpseReactionTarget;
    int tlhCorpseReactionStayTics;
    int tlhCorpseReactionSoundTics;
    bool tlhCorpseReactionPlayed;

    // Centralized dual-wield state. Activation comes from the custom KEYCONF
    // netevent and does not remap R; each weapon still owns its Reload mechanic.
    bool tlhDualWieldActive;
    Weapon tlhDualWieldWeapon;

    int hordeTimer;
    int arenaTimer;
    int survivalTimer;
    int rouletteTimer;
    int modeInitGuard;
    int modeInitMap;
    int previousGameMode;
    bool modeInitialized;

    // ========================================================================
    // PROCEDURAL FIRST-PERSON MOTION
    // These values are intentionally kept on the player so every weapon can
    // consume the same physically-smoothed motion model.
    // ========================================================================
    double tlhAnimStepPhase;
    double tlhAnimSwayX;
    double tlhAnimSwayY;
    double tlhAnimInertiaX;
    double tlhAnimInertiaY;
    double tlhAnimLookX;
    double tlhAnimLookY;

    double tlhAnimWeaponKick;
    double tlhAnimWeaponKickVel;
    double tlhAnimWeaponKickSide;

    double tlhAnimLandingKick;
    double tlhAnimLandingVel;
    double tlhAnimDamageKick;
    double tlhAnimDamageVel;

    double tlhAnimPrevVelX;
    double tlhAnimPrevVelY;
    int tlhAnimLastAmmoSignature;
    int tlhAnimLastHealth;
    Weapon tlhAnimLastWeapon;

    // Per-PSprite transform bookkeeping. The authored weapon-state transform
    // is preserved and the procedural layer is added on top, then removed
    // cleanly on the next tic. This makes the effect apply to Ready/Fire/
    // AltFire/Reload and every other weapon frame without rewriting sprites.
    State tlhAnimLastWeaponPSPState;
    State tlhAnimLastFlashPSPState;

    double tlhAnimAppliedWeaponX;
    double tlhAnimAppliedWeaponY;
    double tlhAnimAppliedWeaponRoll;
    double tlhAnimAppliedWeaponScaleX;
    double tlhAnimAppliedWeaponScaleY;

    double tlhAnimAppliedFlashX;
    double tlhAnimAppliedFlashY;
    double tlhAnimAppliedFlashRoll;
    double tlhAnimAppliedFlashScaleX;
    double tlhAnimAppliedFlashScaleY;

    // Third bookkeeping channel for the left-hand dual-wield overlay.
    State tlhAnimLastDualPSPState;
    double tlhAnimAppliedDualX;
    double tlhAnimAppliedDualY;
    double tlhAnimAppliedDualRoll;
    double tlhAnimAppliedDualScaleX;
    double tlhAnimAppliedDualScaleY;

    // Additional body-acceleration layers for a more physical first-person
    // feel. StopKick handles abrupt deceleration without affecting gameplay.
    double tlhAnimStopKick;
    double tlhAnimStopVel;
    double tlhAnimPrevSpeed;

    // Weapon equip/holster spring. This is purely visual and gives the new
    // weapon a short, weighty settle instead of an instant teleport.
    double tlhAnimDrawKick;
    double tlhAnimDrawVel;

    Default
    {
        // Global tactical health ceiling. Specific game modes may lower it.
        Player.MaxHealth TLH_MAX_HEALTH;
        // Disable stock camera bob. The custom CalcHeight() below owns the visual bob.
        Player.ViewBob 0;
        Player.ViewBobSpeed 20;
        Player.StartItem "Clip", 100;
        Player.WeaponSlot 1, "DashFist", "HookChainsaw";
        Player.WeaponSlot 2, "RecoilPistol", "ServiceRevolver", "OfficerVulkanPistol";
        Player.WeaponSlot 3, "RecoilShotgun", "FastRecoilSSG", "SemiAutoShotgun", "StreetSweeperShotgun";
        // Slot 4 includes the M4A1, rebuilt HeavyChaingun, compact SMG and M60.
        Player.WeaponSlot 4, "TacticalM4A1", "HeavyChaingun", "TLHCompactSMG", "M60MachineGun";
        Player.WeaponSlot 5, "RecoilRocketLauncher";

        Player.WeaponSlot 6, "RecoilPlasmaRifle";
        Player.WeaponSlot 7, "RecoilBFG9000";
        Player.WeaponSlot 8, "AMR99RailRifle";
        Player.WeaponSlot 9, "HellfireProjector";
        Player.WeaponSlot 0, "AirstrikeDesignator";
    }

    // ========================================================================
    // EXPLICIT CHEAT WEAPON LIST
    // GZDoom's generic CheatGive("weapons") scans every registered Weapon class.
    // Use only the real TLH arsenal so removed/legacy classes can never be handed
    // out by IDFA/IDKFA, and keep cheat grants aligned with Player.WeaponSlot.
    // ========================================================================
    override void CheatGive(String name, int amount)
    {
        if (name ~== "weapons")
        {
            if (!player || !player.mo || player.health <= 0)
                return;

            let savedPending = player.PendingWeapon;

            // Slot 1
            GiveInventory("DashFist", 1, true);
            GiveInventory("HookChainsaw", 1, true);

            // Slot 2
            GiveInventory("RecoilPistol", 1, true);
            GiveInventory("ServiceRevolver", 1, true);
            GiveInventory("OfficerVulkanPistol", 1, true);

            // Slot 3
            GiveInventory("RecoilShotgun", 1, true);
            GiveInventory("FastRecoilSSG", 1, true);
            GiveInventory("SemiAutoShotgun", 1, true);
            GiveInventory("StreetSweeperShotgun", 1, true);

            // Slot 4
            GiveInventory("TacticalM4A1", 1, true);
            GiveInventory("HeavyChaingun", 1, true);
            GiveInventory("TLHCompactSMG", 1, true);
            GiveInventory("M60MachineGun", 1, true);

            // Slots 5-9 and 0
            GiveInventory("RecoilRocketLauncher", 1, true);
            GiveInventory("RecoilPlasmaRifle", 1, true);
            GiveInventory("RecoilBFG9000", 1, true);
            GiveInventory("AMR99RailRifle", 1, true);
            GiveInventory("HellfireProjector", 1, true);
            GiveInventory("AirstrikeDesignator", 1, true);

            player.PendingWeapon = savedPending;
            return;
        }

        Super.CheatGive(name, amount);
    }

    // ========================================================================
    // CENTRAL DUAL-WIELD CONTROL
    // ========================================================================

    bool IsTLHDoubleTapWeapon(Weapon weapon)
    {
        if (!weapon)
            return false;

        if (weapon is "RecoilPistol")
            return true;

        if (weapon is "TacticalM4A1")
            return true;

        if (weapon is "OfficerVulkanPistol")
        {
            let vulkan = OfficerVulkanPistol(weapon);
            if (vulkan && vulkan.weaponMode == 0)
                return true;
        }

        return false;
    }

    void SetTLHWeaponDualFlag(Weapon weapon, bool enabled)
    {
        if (!weapon)
            return;

        if (weapon is "RecoilPistol")
        {
            let pistol = RecoilPistol(weapon);
            if (pistol)
                pistol.dualWield = enabled;
        }
        else if (weapon is "TacticalM4A1")
        {
            let m4 = TacticalM4A1(weapon);
            if (m4)
                m4.dualWield = enabled;
        }
        else if (weapon is "OfficerVulkanPistol")
        {
            let vulkan = OfficerVulkanPistol(weapon);
            if (vulkan)
                vulkan.dualWield = enabled;
        }
    }

    void ResetTLHDualForWeaponSwitch()
    {
        if (tlhDualWieldWeapon && tlhDualWieldWeapon != player.ReadyWeapon)
        {
            SetTLHWeaponDualFlag(tlhDualWieldWeapon, false);
            tlhDualWieldWeapon = null;
            tlhDualWieldActive = false;
        }

        if (player.ReadyWeapon && !IsTLHDoubleTapWeapon(player.ReadyWeapon))
        {
            tlhDualWieldActive = false;
            SetTLHWeaponDualFlag(player.ReadyWeapon, false);
        }
    }

    void ToggleTLHDualWield()
    {
        Weapon weapon = player.ReadyWeapon;

        if (!IsTLHDoubleTapWeapon(weapon))
            return;

        bool enable = !tlhDualWieldActive;

        tlhDualWieldActive = enable;

        if (enable)
            tlhDualWieldWeapon = weapon;
        else
            tlhDualWieldWeapon = null;

        SetTLHWeaponDualFlag(weapon, enable);

        State transition = weapon.FindStateByString(
            enable ? "DualOnStart" : "DualOffStart"
        );

        if (transition)
            player.SetPsprite(PSP_WEAPON, transition);
    }

    override void Tick()
    {
        Super.Tick();
        if (!player || !player.mo) return;

        if (player.playerstate == PST_DEAD)
        {
            if (tlhDualWieldWeapon)
                SetTLHWeaponDualFlag(tlhDualWieldWeapon, false);

            tlhDualWieldWeapon = null;
            tlhDualWieldActive = false;
            return;
        }

        // Drive corpse reactions directly from the living local pawn.
        // This does not depend on the HUD handler's consoleplayer cache.
        UpdateTLHCorpseSmellReaction();

        // Tactical armor ceiling is TLH_MAX_ARMOR. Individual game modes can lower it.
        let arm = BasicArmor(FindInventory("BasicArmor"));
        if (arm)
        {
            arm.MaxAmount = TLH_MAX_ARMOR;
            if (arm.Amount > TLH_MAX_ARMOR) arm.Amount = TLH_MAX_ARMOR;
        }

        // Keep the enlarged ammo ceilings explicit at runtime too. This protects
        // players coming from old saves where the inventory classes predate TLH v40.
        EnforceAmmoCap("Clip", TLH_MAX_BULLETS);
        EnforceAmmoCap("Shell", TLH_MAX_SHELLS);
        EnforceAmmoCap("RocketAmmo", TLH_MAX_ROCKETS);
        EnforceAmmoCap("Cell", TLH_MAX_CELLS);

        bool onGround = (Pos.Z <= floorz + 0.5);
        int bt = player.cmd.buttons;
        int obt = player.oldbuttons;
        ResetTLHDualForWeaponSwitch();
        RestoreTLHOwnedWeaponTranslations();

        int gameMode = GetGameMode();

        // Apply map-start loadouts once per map/mode. This is deliberately
        // handled from the player itself so latched game-mode settings work
        // reliably on every map, not only when the player first joins.
        if (!modeInitialized || level.maptime == 0 || modeInitMap != level.levelnum || modeInitGuard != gameMode)
        {
            InitializeGameModeLocal(gameMode);
            previousGameMode = gameMode;
            modeInitMap = level.levelnum;
            modeInitGuard = gameMode;
            modeInitialized = true;
        }

        ApplyGameModeTick(gameMode, onGround, bt);

        // Health and armor limits depend on the selected ruleset.
        int healthCap = TLH_MAX_HEALTH;
        int armorCap = TLH_MAX_ARMOR;
        if (gameMode == 1 || gameMode == 2)
        {
            healthCap = 100;
            armorCap = 100;
        }
        else if (gameMode == 3)
        {
            healthCap = 35;
            armorCap = 35;
        }
        else if (gameMode == 20)
        {
            healthCap = 1;
            armorCap = 0;
        }
        else if (gameMode == 25)
        {
            armorCap = 0;
        }
        else if (gameMode == 30)
        {
            healthCap = 25;
            armorCap = 25;
        }
        else if (gameMode == 32)
        {
            healthCap = 150;
        }

        if (health > healthCap) health = healthCap;

        if (arm)
        {
            arm.MaxAmount = armorCap;
            if (armorCap == 0)
            {
                arm.Amount = 0;
            }
            else if (arm.Amount > armorCap)
            {
                arm.Amount = armorCap;
            }
        }

        // ------------------------------------------------------------
        // M3 / conversion cooldown.
        // ------------------------------------------------------------
        if (akimboCooldown > 0)
            akimboCooldown--;

        if (!(bt & BT_ZOOM))
            akimboButtonHeld = false;

        // ------------------------------------------------------------
        // Double jump
        // ------------------------------------------------------------
        if ((bt & BT_JUMP) && !(obt & BT_JUMP))
        {
            if (gameMode != 1 && !onGround && jumpCount == 0 && waterlevel == 0 && !isSlamming)
            {
                Vel.Z = 12.0;
                jumpCount = 1;
                A_StartSound("weapons/sshotc", CHAN_BODY);
                Spawn("SlideSmoke", Pos - (0, 0, 24));
            }
        }

        // ------------------------------------------------------------
        // Fall / landing
        // ------------------------------------------------------------
        if (!onGround)
        {
            fallTicks++;
            if (Vel.Z < maximumFallSpeed) maximumFallSpeed = Vel.Z;
        }

        if (onGround)
        {
            jumpCount = 0;

            if (isSlamming)
            {
                Spawn("SlamExplosion", Pos);
                isSlamming = false;
                maximumFallSpeed = 0;
                fallTicks = 0;
            }
            else if (!wasOnGround && maximumFallSpeed < -20.0)
            {
                Spawn("SlideSmoke", Pos - (0, 0, 20));
                A_StartSound("weapons/sshoto", CHAN_BODY);
            }

            if (!wasOnGround && (bt & BT_JUMP) && Vel.XY.Length() < 45.0)
            {
                Vel.XY *= 1.35;
                A_StartSound("weapons/sshotc", CHAN_BODY);
            }

            if (wasOnGround)
            {
                maximumFallSpeed = 0;
                fallTicks = 0;
            }
        }

        // ------------------------------------------------------------
        // Slide / Ground Pound
        // ------------------------------------------------------------
        if (gameMode != 1 && (bt & BT_CROUCH) && !(obt & BT_CROUCH))
        {
            if (onGround && Vel.XY.Length() > 2.0 && slideCooldown == 0)
            {
                Thrust(25, angle);
                slideCooldown = 35;
                A_StartSound("weapons/sshoto", CHAN_BODY);
            }
            else if (!onGround && !isSlamming)
            {
                Vel.XY = (0, 0);
                Vel.Z = -50.0;
                isSlamming = true;
                A_StartSound("weapons/rocklf", CHAN_BODY);
            }
        }

        if (slideCooldown > 15 && onGround)
        {
            if ((level.maptime & 3) == 0)
                Spawn("SlideSmoke", Pos - (0, 0, 20));
        }

        if (slideCooldown > 0)
            slideCooldown--;

        let m60 = M60MachineGun(player.ReadyWeapon);
        if (m60 && m60.braced && onGround)
            Vel.XY *= 0.84;

        // Feed the procedural camera/weapon animation state once per tic.
        UpdateTLHProceduralMotion(onGround, bt, obt);

        wasOnGround = onGround;
    }

    // ========================================================================
    // PLAYER CORPSE SMELL REACTION
    // ========================================================================
    void UpdateTLHCorpseSmellReaction()
    {
        if (!player || player.playerstate != PST_LIVE || Health <= 0)
            return;

        // Wait out a reaction before considering another sound. Tics are used
        // instead of checking actor-owned sound channels, since this is a 2D
        // local reaction that is not attached to the corpse.
        if (tlhCorpseReactionSoundTics > 0)
        {
            tlhCorpseReactionSoundTics--;
            return;
        }

        Actor closestCorpse = null;
        double closestDistSq = 72.0 * 72.0;

        ThinkerIterator corpseIt = ThinkerIterator.Create("Actor");
        Actor candidate;
        while ((candidate = Actor(corpseIt.Next())) != null)
        {
            if (candidate == self || !(candidate is "PlayerPawn") || candidate.Health > 0)
                continue;

            double dz = abs(candidate.Pos.Z - Pos.Z);
            if (dz > 64.0)
                continue;

            double dx = candidate.Pos.X - Pos.X;
            double dy = candidate.Pos.Y - Pos.Y;
            double distSq = dx * dx + dy * dy;

            if (distSq <= closestDistSq)
            {
                closestDistSq = distSq;
                closestCorpse = candidate;
            }
        }

        if (!closestCorpse)
        {
            tlhCorpseReactionTarget = null;
            tlhCorpseReactionStayTics = 0;
            tlhCorpseReactionPlayed = false;
            return;
        }

        if (closestCorpse != tlhCorpseReactionTarget)
        {
            tlhCorpseReactionTarget = closestCorpse;
            tlhCorpseReactionStayTics = 0;
            tlhCorpseReactionPlayed = false;
        }

        if (tlhCorpseReactionPlayed)
            return;

        tlhCorpseReactionStayTics++;
        if (tlhCorpseReactionStayTics < 42) // about 1.2 seconds
            return;

        // Keep IDs literal so the sound linker can resolve them at compile/load.
        int pick = random(1, 5);
        double soundLength = 0.0;
        switch (pick)
        {
            case 1:
                S_StartSound("REAC01", CHAN_BODY, CHANF_UI, 1.0, ATTN_NONE);
                soundLength = S_GetLength("REAC01");
                break;
            case 2:
                S_StartSound("REAC02", CHAN_BODY, CHANF_UI, 1.0, ATTN_NONE);
                soundLength = S_GetLength("REAC02");
                break;
            case 3:
                S_StartSound("REAC03", CHAN_BODY, CHANF_UI, 1.0, ATTN_NONE);
                soundLength = S_GetLength("REAC03");
                break;
            case 4:
                S_StartSound("REAC04", CHAN_BODY, CHANF_UI, 1.0, ATTN_NONE);
                soundLength = S_GetLength("REAC04");
                break;
            default:
                S_StartSound("REAC05", CHAN_BODY, CHANF_UI, 1.0, ATTN_NONE);
                soundLength = S_GetLength("REAC05");
                break;
        }

        tlhCorpseReactionSoundTics = soundLength > 0.0
            ? max(1, int(soundLength * 35.0) + 2)
            : 70;
        tlhCorpseReactionPlayed = true;
    }

    // Restore each owned weapon's class-default translation. WorldThingSpawned
    // deliberately clears translation from ground pickups so drops keep their
    // original palette; equipped weapons regain the intended HUD recolor here.
    void RestoreTLHOwnedWeaponTranslations()
    {
        Inventory item = Inv;
        while (item)
        {
            Inventory nextItem = item.Inv;
            if (item is "Weapon" && item.Owner == self)
            {
                let classDefault = GetDefaultByType(item.GetClass());
                if (classDefault)
                    item.Translation = classDefault.Translation;
            }
            item = nextItem;
        }
    }

    // ========================================================================
    // ADVANCED FIRST-PERSON MOTION
    // ========================================================================

    override void CalcHeight()
    {
        // Keep GZDoom's collision/height handling and native bob bookkeeping,
        // but disable its final visual bob through Player.ViewBob 0 above.
        Super.CalcHeight();

        if (!player || player.playerstate != PST_LIVE)
            return;

        bool grounded = (Pos.Z <= floorz + 0.5);
        double speed = Vel.XY.Length();
        double speed01 = clamp(speed / 12.0, 0.0, 1.0);
        double bobSpeed = clamp(player.GetWBobSpeed(), 0.45, 2.40);

        if (grounded && speed01 > 0.025 && !(player.cheats & CF_NOCLIP2))
        {
            // Faster movement increases stride frequency rather than merely
            // increasing amplitude. This avoids the "sine wave in a corridor"
            // feel of simple headbob implementations.
            tlhAnimStepPhase += (6.0 + speed01 * 12.0) * bobSpeed;
        }
        else
        {
            // Let the gait phase continue drifting very slowly when stopped so
            // the transition back into walking never snaps to a new phase.
            tlhAnimStepPhase += 0.65 * bobSpeed;
        }

        while (tlhAnimStepPhase >= 36000.0)
            tlhAnimStepPhase -= 36000.0;
        while (tlhAnimStepPhase < 0.0)
            tlhAnimStepPhase += 36000.0;

        double cameraBob = 0.0;
        if (grounded && speed01 > 0.025 && !(player.cheats & CF_NOCLIP2))
        {
            double gait = sin(tlhAnimStepPhase);
            double gaitDouble = sin(tlhAnimStepPhase * 2.0);
            double crouchFactor = clamp(player.crouchfactor, 0.0, 1.0);

            // Small lateral/harmonic component gives footsteps a subtle weight
            // shift instead of a perfectly vertical piston motion.
            double strideLift = gaitDouble * (0.42 + 1.20 * speed01);
            double strideRollFeel = gait * (0.12 * speed01);

            // Each footfall gets a short compression phase. The positive half
            // of the cycle lifts the view; the negative half produces the
            // characteristic planted-foot dip, making the headbob asymmetric
            // instead of a sterile sinusoid.
            double footCompression = max(0.0, -gaitDouble) * (0.18 + 0.55 * speed01);

            cameraBob = strideLift + strideRollFeel - footCompression;

            double crouchBobBlend = 0.52 + 0.48 * crouchFactor;
            cameraBob *= crouchBobBlend;
        }
        else if (grounded)
        {
            // Barely visible breathing/micro-movement while standing still.
            cameraBob = sin(double(level.time) * 0.18 * TLH_RAD_TO_DEG) * 0.07;
        }
        else
        {
            // Airborne motion is calmer than running, but not perfectly rigid.
            cameraBob = sin(double(level.time) * 0.13 * TLH_RAD_TO_DEG) * 0.06;
        }

        // Landing and damage are spring values, so they overshoot and settle
        // naturally instead of teleporting the camera by a fixed amount.
        cameraBob -= tlhAnimLandingKick * 0.34;
        cameraBob -= tlhAnimDamageKick * 0.12;

        player.viewz += cameraBob;

        // Preserve GZDoom's normal collision safety after our extra visual bob.
        if (player.viewz > ceilingz - 4)
            player.viewz = ceilingz - 4;
        if (player.viewz < floorz + 4)
            player.viewz = floorz + 4;
    }

    override Vector2 BobWeapon(double ticfrac)
    {
        if (!player)
            return (0, 0);

        let weapon = player.ReadyWeapon;
        if (!weapon || weapon.bDontBob)
            return (0, 0);

        // Never apply custom weapon bob while the engine is switching weapons.
        // Otherwise the old PSprite's moving bob is layered over A_Lower/A_Raise.
        if (player.PendingWeapon != WP_NOCHANGE)
            return (0, 0);

        double speed = Vel.XY.Length();
        // The revolver combines classic movement bob into its own Ready-state
        // offset. Do not apply a second player-level transform over its authored
        // recoil/reload offsets, which previously caused vertical jitter.
        if (weapon is "ServiceRevolver")
            return (0, 0);
        double speed01 = clamp(speed / 18.0, 0.0, 1.0);
        double bobSpeed = clamp(player.GetWBobSpeed(), 0.45, 2.40);
        // Reuse TLH's existing movement phase: PlayerInfo's native BobTimer
        // is not exposed to ZScript in GZDoom 4.14.2. ticfrac smooths the
        // phase between tics without creating a second gait clock.
        double phase = tlhAnimStepPhase +
            ((6.0 + speed01 * 12.0) * bobSpeed * ticfrac);
        double classicBob = sqrt(max(player.bob, 0.0)) * 1.10;
        double gait = sin(phase);
        double gaitDouble = sin(phase * 2.0);
        double weight = GetTLHWeaponMotionWeight(weapon);

        double rangeX = weapon.BobRangeX;
        double rangeY = weapon.BobRangeY;
        if (rangeX <= 0.001) rangeX = 1.0;
        if (rangeY <= 0.001) rangeY = 1.0;

        double intensity = (player.WeaponState & WF_WEAPONBOBBING) ?
            1.0 : player.GetWBobFire();

        double crouchFactor = clamp(player.crouchfactor, 0.0, 1.0);
        double airBlend = (Pos.Z <= floorz + 0.5) ? 0.0 : 1.0;
        double idleBlend = clamp(1.0 - speed01 * 2.2, 0.0, 1.0);

        // Layer 1: classic DOOM II gait. The second harmonic adds the familiar
        // vertical bounce without the old extra half-frequency sway.
        double walkX = gait * classicBob;
        double walkY = gaitDouble * classicBob * (0.32 + 0.08 * crouchFactor);

        // Layer 2: velocity and acceleration sway.
        double worldForwardX = cos(angle);
        double worldForwardY = sin(angle);
        double worldRightX = sin(angle);
        double worldRightY = -cos(angle);

        double forwardVelocity = Vel.X * worldForwardX + Vel.Y * worldForwardY;
        double sideVelocity = Vel.X * worldRightX + Vel.Y * worldRightY;

        double velocitySwayX = -sideVelocity * 0.115;
        double velocitySwayY = abs(forwardVelocity) * 0.020;

        // Layer 3: look inertia. cmd yaw/pitch is smoothed in the player tick,
        // keeping quick mouse movement from snapping the PSprite.
        double lookX = tlhAnimLookX * 0.90;
        double lookY = -tlhAnimLookY * 0.48;

        // Primitive weapon sway: a small smoothed offset opposing view motion.
        // It is deliberately subtle so the weapon follows the view without
        // feeling like a second camera-bob system.
        double simpleSwayX = clamp(tlhAnimLookX * 1.35, -2.0, 2.0);
        double simpleSwayY = clamp(-tlhAnimLookY * 0.90, -1.25, 1.25);

        // Layer 4: braking/settling. This is the visual memory of the body
        // continuing to move for a fraction of a second after the player stops.
        double sprintSettle = speed01 * speed01 * 0.34;
        double stopX = tlhAnimStopKick * 0.30;
        double stopY = -abs(tlhAnimStopKick) * 0.12;

        // Layer 5: recoil and landing compression.
        double recoilY = -tlhAnimWeaponKick * (0.80 + 0.22 * weight);
        double recoilX = tlhAnimWeaponKickSide * 0.48;
        double landingY = tlhAnimLandingKick * 0.26;
        double damageY = tlhAnimDamageKick * 0.10;

        // Standing still gets a tiny breathing motion. In the air the gait is
        // mostly suppressed and the weapon enters a light floating state.
        double idleX = sin(double(level.time) * 0.105 * TLH_RAD_TO_DEG) * 0.16 * idleBlend;
        double idleY = cos(double(level.time) * 4.7555497) * 0.13 * idleBlend;
        double airX = sin(double(level.time) * 0.07 * TLH_RAD_TO_DEG) * 0.08 * airBlend;
        double airY = cos(double(level.time) * 0.055 * TLH_RAD_TO_DEG) * 0.18 * airBlend;

        // Avoid shadowing Actor.X/Y: use explicit names for local PSprite offsets.
        double weaponBobX =
            (walkX * 0.92 + velocitySwayX + tlhAnimSwayX +
             tlhAnimInertiaX + lookX + simpleSwayX + stopX +
             recoilX + idleX + airX) * weight;

        double weaponBobY =
            (walkY * 0.90 + velocitySwayY + tlhAnimSwayY +
             tlhAnimInertiaY + lookY + simpleSwayY + sprintSettle +
             stopY + recoilY + landingY + damageY + idleY + airY) * weight;

        // Reduce the visual amplitude while airborne and while crouched.
        weaponBobX *= intensity * rangeX * (1.0 - 0.32 * airBlend);
        weaponBobY *= intensity * rangeY * (1.0 - 0.18 * airBlend);

        // Keep authored weapon ranges sane even for weapons that were never
        // intended to use such large procedural offsets.
        weaponBobX = clamp(weaponBobX, -11.0, 11.0);
        weaponBobY = clamp(weaponBobY, -15.0, 15.0);

        return (weaponBobX, weaponBobY);
    }

    // Apply the procedural transform to the actual weapon PSprite and its
    // flash PSprite. This is the visible HUD weapon: x/y sway, roll, recoil,
    // squash/stretch and weapon-specific mass are all applied here.
    //
    // GZDoom exposes PSprite x/y/scale/rotation and calls the weapon's
    // PSpriteTick while processing weapon overlays. The authored state remains
    // intact because the procedural layer is tracked and removed before the
    // next modification when the PSprite is still in the same state.
    void ApplyTLHWeaponPSpriteMotion(PSprite psp)
    {
        if (!psp || !player || !player.mo || !player.ReadyWeapon)
            return;

        Weapon weapon = player.ReadyWeapon;
        if (psp.Caller != weapon)
            return;

        bool isWeaponPSP = (psp.ID == PSP_WEAPON);
        bool isFlashPSP = (psp.ID == PSP_FLASH);
        bool isDualPSP = (psp.ID == TLH_AKIMBO_LAYER);
        if (!isWeaponPSP && !isFlashPSP && !isDualPSP)
            return;

        // Apply the weapon's embedded palette to every non-flash PSprite state.
        // This is the procedural part: the same mapping follows Ready, Fire,
        // Reload, Select, Deselect and the dual-wield overlay automatically.
        if (!isFlashPSP && (isWeaponPSP || isDualPSP))
        {
            let weaponDefault = GetDefaultByType(weapon.GetClass());
            psp.Translation = weaponDefault ? weaponDefault.Translation : weapon.Translation;
        }

        State lastState = isWeaponPSP ? tlhAnimLastWeaponPSPState :
                          (isFlashPSP ? tlhAnimLastFlashPSPState : tlhAnimLastDualPSPState);
        bool sameState = (lastState == psp.CurState);

        // Remove only our previous procedural contribution if the authored
        // state is unchanged. On a state transition GZDoom has already applied
        // the new state's own transform, so never subtract the old one from it.
        if (sameState)
        {
            if (isWeaponPSP)
            {
                psp.x -= tlhAnimAppliedWeaponX;
                psp.y -= tlhAnimAppliedWeaponY;
                psp.rotation -= tlhAnimAppliedWeaponRoll;
                if (abs(tlhAnimAppliedWeaponScaleX) > 0.0001)
                    psp.scale.x /= tlhAnimAppliedWeaponScaleX;
                if (abs(tlhAnimAppliedWeaponScaleY) > 0.0001)
                    psp.scale.y /= tlhAnimAppliedWeaponScaleY;
            }
            else if (isFlashPSP)
            {
                psp.x -= tlhAnimAppliedFlashX;
                psp.y -= tlhAnimAppliedFlashY;
                psp.rotation -= tlhAnimAppliedFlashRoll;
                if (abs(tlhAnimAppliedFlashScaleX) > 0.0001)
                    psp.scale.x /= tlhAnimAppliedFlashScaleX;
                if (abs(tlhAnimAppliedFlashScaleY) > 0.0001)
                    psp.scale.y /= tlhAnimAppliedFlashScaleY;
            }
            else
            {
                psp.x -= tlhAnimAppliedDualX;
                psp.y -= tlhAnimAppliedDualY;
                psp.rotation -= tlhAnimAppliedDualRoll;
                if (abs(tlhAnimAppliedDualScaleX) > 0.0001)
                    psp.scale.x /= tlhAnimAppliedDualScaleX;
                if (abs(tlhAnimAppliedDualScaleY) > 0.0001)
                    psp.scale.y /= tlhAnimAppliedDualScaleY;
            }
        }
        else
        {
            // New state: clear bookkeeping because the state's own transform
            // is now the baseline for this PSprite.
            if (isWeaponPSP)
            {
                tlhAnimAppliedWeaponX = 0;
                tlhAnimAppliedWeaponY = 0;
                tlhAnimAppliedWeaponRoll = 0;
                tlhAnimAppliedWeaponScaleX = 1.0;
                tlhAnimAppliedWeaponScaleY = 1.0;
            }
            else if (isFlashPSP)
            {
                tlhAnimAppliedFlashX = 0;
                tlhAnimAppliedFlashY = 0;
                tlhAnimAppliedFlashRoll = 0;
                tlhAnimAppliedFlashScaleX = 1.0;
                tlhAnimAppliedFlashScaleY = 1.0;
            }
            else
            {
                tlhAnimAppliedDualX = 0;
                tlhAnimAppliedDualY = 0;
                tlhAnimAppliedDualRoll = 0;
                tlhAnimAppliedDualScaleX = 1.0;
                tlhAnimAppliedDualScaleY = 1.0;
            }
        }

        if (isWeaponPSP)
            tlhAnimLastWeaponPSPState = psp.CurState;
        else if (isFlashPSP)
            tlhAnimLastFlashPSPState = psp.CurState;
        else
            tlhAnimLastDualPSPState = psp.CurState;

        double visualScaleX = 1.0;
        double visualScaleY = 1.0;
        double visualOffsetX = 0.0;
        double visualOffsetY = 0.0;
        double visualBaseRoll = 0.0;
        double visualSway = 1.0;
        GetTLHWeaponVisualProfile(weapon, visualScaleX, visualScaleY,
            visualOffsetX, visualOffsetY, visualBaseRoll, visualSway);

        double speed01 = clamp(Vel.XY.Length() / 18.0, 0.0, 1.0);
        double weight = GetTLHWeaponMotionWeight(weapon);
        double crouchFactor = clamp(player.crouchfactor, 0.0, 1.0);
        double airBlend = (Pos.Z <= floorz + 0.5) ? 0.0 : 1.0;

        // The weapon PSprite gets the full body/aim simulation. The flash is
        // deliberately damped so muzzle flashes remain attached to the gun
        // without becoming a second source of screen shake.
        double weaponFactor = isWeaponPSP ? 1.0 : (isFlashPSP ? 0.42 : 0.86);

        double handSign = isDualPSP ? -1.0 : 1.0;

        // Strafe body tilt and vertical-flight tilt make the weapon react to
        // actual player movement rather than only to a timer.
        double worldRightX = sin(angle);
        double worldRightY = -cos(angle);
        double sideVelocity = Vel.X * worldRightX + Vel.Y * worldRightY;
        double bodyTilt = clamp(-sideVelocity * 0.055, -3.2, 3.2);
        double airTilt = clamp(-Vel.Z * 0.050, -3.0, 3.0) * airBlend;
        double drawRoll = -tlhAnimDrawKick * 0.10;

        double stepRoll = sin(tlhAnimStepPhase) * (0.65 + 1.10 * speed01);
        double swayRoll = -tlhAnimSwayX * 0.62;
        double inertiaRoll = -tlhAnimInertiaX * 0.40;
        double lookRoll = -tlhAnimLookX * 0.52;
        double recoilRoll = tlhAnimWeaponKickSide * (isWeaponPSP ? 1.15 : 0.38);
        double landingRoll = tlhAnimLandingKick * 0.10;
        double stopRoll = tlhAnimStopKick * 0.24;

        double totalRoll =
            visualBaseRoll + drawRoll +
            (stepRoll + swayRoll + inertiaRoll + lookRoll +
             recoilRoll + landingRoll + stopRoll + bodyTilt + airTilt) *
            visualSway * weaponFactor * (0.78 + 0.22 * weight);

        // Heavy weapons resist rotational movement more than pistols.
        String cls = weapon.GetClassName();
        if (cls == "M60MachineGun" || cls == "RecoilRocketLauncher" ||
            cls == "RecoilBFG9000" || cls == "AMR99RailRifle")
            totalRoll *= 0.60;
        else if (cls == "RecoilPistol" || cls == "OfficerVulkanPistol")
            totalRoll *= 1.12;

        if (isDualPSP)
            totalRoll = -totalRoll * 0.90;

        totalRoll = clamp(totalRoll, -4.25, 4.25);

        // Additional direct PSprite sway. BobWeapon() supplies the base gait;
        // this is the higher-frequency weapon-body relationship layered on top.
        double swayX =
            (tlhAnimSwayX * 1.10 + tlhAnimInertiaX * 0.85 +
             tlhAnimLookX * 0.68 + tlhAnimStopKick * 0.40) * visualSway * weaponFactor;

        double swayY =
            (tlhAnimSwayY * 0.75 + tlhAnimInertiaY * 0.55 -
             tlhAnimLookY * 0.40) * visualSway * weaponFactor;

        // Crouching lowers the weapon slightly. Airborne weapons float upward
        // by a tiny amount, while recoil dominates the vertical axis during fire.
        double crouchY = -(1.0 - crouchFactor) * (1.4 + 1.2 * weight);
        double airFloatY = airBlend * cos(double(level.time) * 0.09 * TLH_RAD_TO_DEG) * 0.35;
        double recoilY = -tlhAnimWeaponKick * (isWeaponPSP ? 0.92 : 0.30);
        double recoilX = tlhAnimWeaponKickSide * (isWeaponPSP ? 0.56 : 0.20);
        double landingY = tlhAnimLandingKick * (isWeaponPSP ? 0.30 : 0.12);
        double damageY = tlhAnimDamageKick * (isWeaponPSP ? 0.12 : 0.05);
        double drawY = tlhAnimDrawKick * (isWeaponPSP ? 0.72 : 0.28);
        double drawX = -tlhAnimDrawKick * (isWeaponPSP ? 0.06 : 0.02);

        double totalX = visualOffsetX + swayX + recoilX + drawX;
        if (isDualPSP)
            totalX *= handSign;
        double totalY = visualOffsetY + swayY + crouchY + airFloatY +
                        recoilY + landingY + damageY + drawY;

        totalX = clamp(totalX, -12.0, 12.0);
        totalY = clamp(totalY, -18.0, 18.0);

        // Procedural squash/stretch during recoil and landing. Because this is
        // applied to the live PSprite's current scale, every authored frame of
        // the custom weapon receives the same visual treatment.
        double recoilCompression = clamp(tlhAnimWeaponKick * 0.010, 0.0, 0.11);
        double landingCompression = clamp(tlhAnimLandingKick * 0.004, 0.0, 0.035);
        double scaleX = visualScaleX * (1.0 + recoilCompression * 0.28);
        double scaleY = visualScaleY * (1.0 - recoilCompression - landingCompression);

        // Keep alternate weapon frames from accidentally becoming invisible.
        if (scaleX < 0.60) scaleX = 0.60;
        if (scaleY < 0.60) scaleY = 0.60;

        psp.x += totalX;
        psp.y += totalY;
        psp.rotation += totalRoll;
        psp.scale.x *= scaleX;
        psp.scale.y *= scaleY;

        if (isWeaponPSP)
        {
            tlhAnimAppliedWeaponX = totalX;
            tlhAnimAppliedWeaponY = totalY;
            tlhAnimAppliedWeaponRoll = totalRoll;
            tlhAnimAppliedWeaponScaleX = scaleX;
            tlhAnimAppliedWeaponScaleY = scaleY;
        }
        else if (isFlashPSP)
        {
            tlhAnimAppliedFlashX = totalX;
            tlhAnimAppliedFlashY = totalY;
            tlhAnimAppliedFlashRoll = totalRoll;
            tlhAnimAppliedFlashScaleX = scaleX;
            tlhAnimAppliedFlashScaleY = scaleY;
        }
        else
        {
            tlhAnimAppliedDualX = totalX;
            tlhAnimAppliedDualY = totalY;
            tlhAnimAppliedDualRoll = totalRoll;
            tlhAnimAppliedDualScaleX = scaleX;
            tlhAnimAppliedDualScaleY = scaleY;
        }
    }

    // Per-weapon presentation profile. This changes only the first-person
    // appearance. Damage, spread, ammo use and all gameplay values remain
    // untouched. Importantly, the multiplier is applied to the live PSprite,
    // so Fire/AltFire/Reload/Select/Ready frames inherit the same shape.
    void GetTLHWeaponVisualProfile(Weapon weapon,
        out double scaleX, out double scaleY,
        out double offsetX, out double offsetY,
        out double baseRoll, out double sway)
    {
        scaleX = 1.0;
        scaleY = 1.0;
        offsetX = 0.0;
        offsetY = 0.0;
        baseRoll = 0.0;
        sway = 1.0;

        if (!weapon) return;

        String cls = weapon.GetClassName();

        if (cls == "RecoilPistol")
        {
            scaleX = 0.98; scaleY = 1.04; offsetY = 0.6; sway = 1.10;
        }
        else if (cls == "ServiceRevolver")
        {
            scaleX = 0.94; scaleY = 1.00; offsetY = 0.6; sway = 1.06;
        }
        else if (cls == "OfficerVulkanPistol")
        {
            scaleX = 0.96; scaleY = 1.06; offsetY = 0.4; sway = 1.12;
        }
        else if (cls == "RecoilShotgun")
        {
            scaleX = 0.98; scaleY = 1.10; offsetY = 0.8; sway = 0.96;
        }
        else if (cls == "StreetSweeperShotgun")
        {
            scaleX = 1.00; scaleY = 1.12; offsetY = 0.9; sway = 0.98;
        }
        else if (cls == "FastRecoilSSG")
        {
            scaleX = 0.98; scaleY = 1.13; offsetY = 1.0; sway = 0.90;
        }
        else if (cls == "SemiAutoShotgun")
        {
            scaleX = 1.00; scaleY = 1.16; offsetY = 0.8; sway = 0.94;
        }
        else if (cls == "TacticalM4A1")
        {
            scaleX = 1.02; scaleY = 1.08; offsetY = 0.4; sway = 0.86;
        }
        else if (cls == "M60MachineGun")
        {
            scaleX = 0.99; scaleY = 1.12; offsetY = 1.4; sway = 0.68;
        }
        else if (cls == "HeavyChaingun")
        {
            scaleX = 1.06; scaleY = 1.13; offsetY = 1.7; baseRoll = -0.18; sway = 0.54;
        }
        else if (cls == "TLHCompactSMG")
        {
            scaleX = 0.99; scaleY = 1.05; offsetY = 0.35; baseRoll = -0.08; sway = 0.88;
        }
        else if (cls == "RecoilRocketLauncher")
        {
            scaleX = 1.03; scaleY = 1.10; offsetY = 1.3; sway = 0.66;
        }
        else if (cls == "RecoilPlasmaRifle")
        {
            scaleX = 1.00; scaleY = 1.09; offsetY = 0.6; sway = 0.74;
        }
        else if (cls == "RecoilBFG9000")
        {
            scaleX = 0.98; scaleY = 1.12; offsetY = 1.8; sway = 0.58;
        }
        else if (cls == "AMR99RailRifle")
        {
            scaleX = 0.96; scaleY = 1.14; offsetY = 1.0; sway = 0.62;
        }
        else if (cls == "HellfireProjector")
        {
            scaleX = 0.82; scaleY = 0.86; offsetY = 0.7; sway = 0.68;
        }
        else if (cls == "AirstrikeDesignator")
        {
            scaleX = 1.03; scaleY = 1.08; offsetY = 0.7; sway = 0.78;
        }
        else if (cls == "DashFist")
        {
            scaleX = 1.02; scaleY = 1.05; offsetY = 0.4; sway = 1.14;
        }
        else if (cls == "HookChainsaw")
        {
            scaleX = 1.00; scaleY = 1.08; offsetY = 0.8; sway = 1.00;
        }
    }

    double GetTLHWeaponMotionWeight(Weapon weapon)
    {
        if (!weapon) return 1.0;

        String cls = weapon.GetClassName();

        // Small weapons react more to body motion.
        if (cls == "RecoilPistol" || cls == "OfficerVulkanPistol") return 1.08;
        if (cls == "DashFist" || cls == "HookChainsaw") return 1.12;

        // Shotguns are heavy but still have a strong physical swing.
        if (cls == "RecoilShotgun" || cls == "FastRecoilSSG" || cls == "SemiAutoShotgun") return 0.92;

        // Carbines and compact automatics settle quickly.
        if (cls == "TacticalM4A1") return 0.82;
        if (cls == "TLHCompactSMG") return 0.78;

        // Very heavy weapons move less but hit harder when they recoil.
        if (cls == "M60MachineGun") return 0.66;
        if (cls == "HeavyChaingun") return 0.64;
        if (cls == "RecoilRocketLauncher") return 0.62;
        if (cls == "RecoilPlasmaRifle") return 0.70;
        if (cls == "RecoilBFG9000") return 0.55;
        if (cls == "AMR99RailRifle") return 0.58;
        if (cls == "HellfireProjector") return 0.60;
        if (cls == "AirstrikeDesignator") return 0.74;

        // Vanilla weapons that might be present in old saves.
        if (cls == "Pistol") return 1.05;
        if (cls == "Shotgun") return 0.92;
        if (cls == "SuperShotgun") return 0.88;
        if (cls == "Chaingun") return 0.84;
        if (cls == "RocketLauncher") return 0.64;
        if (cls == "PlasmaRifle") return 0.72;
        if (cls == "BFG9000") return 0.55;

        return 0.90;
    }

    int GetTLHAmmoSignature()
    {
        // A simple aggregate signature is used only for detecting a firing
        // event. It is not a gameplay resource calculation.
        return CountInv("Clip") + CountInv("Shell") +
               CountInv("RocketAmmo") + CountInv("Cell");
    }

    void UpdateTLHProceduralMotion(bool onGroundNow, int bt, int oldbt)
    {
        // ------------------------------------------------------------
        // Look inertia
        // ------------------------------------------------------------
        double targetLookX = clamp(double(player.cmd.yaw) / 1024.0, -1.0, 1.0);
        double targetLookY = clamp(double(player.cmd.pitch) / 1024.0, -1.0, 1.0);

        tlhAnimLookX += (targetLookX - tlhAnimLookX) * 0.30;
        tlhAnimLookY += (targetLookY - tlhAnimLookY) * 0.30;

        // ------------------------------------------------------------
        // Velocity / acceleration based sway
        // ------------------------------------------------------------
        double worldForwardX = cos(angle);
        double worldForwardY = sin(angle);
        double worldRightX = sin(angle);
        double worldRightY = -cos(angle);

        double forwardVelocity = Vel.X * worldForwardX + Vel.Y * worldForwardY;
        double sideVelocity = Vel.X * worldRightX + Vel.Y * worldRightY;

        double targetSwayX = -sideVelocity * 0.075;
        double targetSwayY = abs(forwardVelocity) * 0.010;

        tlhAnimSwayX += (targetSwayX - tlhAnimSwayX) * 0.20;
        tlhAnimSwayY += (targetSwayY - tlhAnimSwayY) * 0.18;

        double previousSpeed = tlhAnimPrevSpeed;
        double currentSpeed = Vel.XY.Length();
        if (onGroundNow && previousSpeed > 4.0 && currentSpeed < previousSpeed - 1.5)
        {
            double stopDelta = clamp(previousSpeed - currentSpeed, 0.0, 12.0);
            tlhAnimStopVel += stopDelta * 0.060;
        }
        tlhAnimPrevSpeed = currentSpeed;

        double accelerationX = Vel.X - tlhAnimPrevVelX;
        double accelerationY = Vel.Y - tlhAnimPrevVelY;

        double forwardAcceleration = accelerationX * worldForwardX +
                                     accelerationY * worldForwardY;
        double sideAcceleration = accelerationX * worldRightX +
                                  accelerationY * worldRightY;

        double targetInertiaX = clamp(-sideAcceleration * 0.16, -2.4, 2.4);
        double targetInertiaY = clamp(-forwardAcceleration * 0.075, -1.5, 1.5);

        tlhAnimInertiaX += (targetInertiaX - tlhAnimInertiaX) * 0.22;
        tlhAnimInertiaY += (targetInertiaY - tlhAnimInertiaY) * 0.22;

        tlhAnimPrevVelX = Vel.X;
        tlhAnimPrevVelY = Vel.Y;

        // ------------------------------------------------------------
        // Weapon switching reset
        // ------------------------------------------------------------
        if (tlhAnimLastWeapon != player.ReadyWeapon)
        {
            tlhAnimLastWeapon = player.ReadyWeapon;
            tlhAnimLastAmmoSignature = GetTLHAmmoSignature();
            tlhAnimWeaponKick = 0;
            tlhAnimWeaponKickVel = 0;
            tlhAnimWeaponKickSide = 0;

            // Fresh weapon presentation: start slightly low, then let the
            // spring settle the weapon into the new stance.
            tlhAnimDrawKick = 5.0;
            tlhAnimDrawVel = 0.0;
        }

        // ------------------------------------------------------------
        // Ammo delta -> procedural firing recoil
        // ------------------------------------------------------------
        int ammoSignature = GetTLHAmmoSignature();
        if (tlhAnimLastAmmoSignature >= 0 && ammoSignature < tlhAnimLastAmmoSignature)
        {
            int spent = tlhAnimLastAmmoSignature - ammoSignature;
            if (spent > 0 && spent < 96 && player.ReadyWeapon != null)
            {
                String cls = player.ReadyWeapon.GetClassName();
                double impulse = 1.15 + double(min(spent, 8)) * 0.20;

                if (cls == "RecoilPistol" || cls == "OfficerVulkanPistol")
                    impulse *= 0.90;
                else if (cls == "RecoilShotgun" || cls == "SemiAutoShotgun")
                    impulse *= 1.45;
                else if (cls == "FastRecoilSSG")
                    impulse *= 1.70;
                else if (cls == "M60MachineGun" || cls == "HeavyChaingun")
                    impulse *= 1.25;
                else if (cls == "RecoilRocketLauncher" || cls == "HellfireProjector")
                    impulse *= 2.00;
                else if (cls == "RecoilPlasmaRifle")
                    impulse *= 0.72;
                else if (cls == "AMR99RailRifle")
                    impulse *= 1.80;
                else if (cls == "RecoilBFG9000")
                    impulse *= 2.60;

                // Alternating lateral impulse prevents automatic fire from
                // drifting permanently in one direction.
                double sideImpulse = ((level.time & 1) == 0) ? 1.0 : -1.0;

                tlhAnimWeaponKickVel += impulse;
                tlhAnimWeaponKickSide += sideImpulse * impulse * 0.16;
            }
        }
        tlhAnimLastAmmoSignature = ammoSignature;

        // Melee weapons do not consume ammo, so give their first swing a small
        // procedural body kick on the attack edge.
        if ((bt & BT_ATTACK) && !(oldbt & BT_ATTACK) && player.ReadyWeapon != null)
        {
            String meleeClass = player.ReadyWeapon.GetClassName();
            if (meleeClass == "DashFist")
            {
                tlhAnimWeaponKickVel += 0.90;
                tlhAnimWeaponKickSide -= 0.22;
            }
            else if (meleeClass == "HookChainsaw")
            {
                tlhAnimWeaponKickVel += 0.55;
                tlhAnimWeaponKickSide += 0.18;
            }
        }

        // ------------------------------------------------------------
        // Landing kick
        // ------------------------------------------------------------
        if (onGroundNow && !wasOnGround && maximumFallSpeed < -10.0)
        {
            double impact = clamp((-maximumFallSpeed - 8.0) * 0.12, 0.8, 5.0);
            tlhAnimLandingVel += impact;
        }

        // ------------------------------------------------------------
        // Damage reaction
        // ------------------------------------------------------------
        if (tlhAnimLastHealth >= 0 && health < tlhAnimLastHealth)
        {
            int delta = tlhAnimLastHealth - health;
            double hit = clamp(double(delta) * 0.06, 0.35, 3.5);
            tlhAnimDamageVel += hit;
        }
        tlhAnimLastHealth = health;

        // ------------------------------------------------------------
        // Spring integration
        // ------------------------------------------------------------
        tlhAnimWeaponKick += tlhAnimWeaponKickVel;
        tlhAnimWeaponKickVel -= tlhAnimWeaponKick * 0.20;
        tlhAnimWeaponKickVel *= 0.70;
        tlhAnimWeaponKick = clamp(tlhAnimWeaponKick, 0.0, 18.0);
        tlhAnimWeaponKickSide *= 0.78;

        tlhAnimLandingKick += tlhAnimLandingVel;
        tlhAnimLandingVel -= tlhAnimLandingKick * 0.24;
        tlhAnimLandingVel *= 0.68;
        tlhAnimLandingKick = clamp(tlhAnimLandingKick, 0.0, 8.0);

        tlhAnimDamageKick += tlhAnimDamageVel;
        tlhAnimDamageVel -= tlhAnimDamageKick * 0.28;
        tlhAnimDamageVel *= 0.64;
        tlhAnimDamageKick = clamp(tlhAnimDamageKick, 0.0, 6.0);

        tlhAnimStopKick += tlhAnimStopVel;
        tlhAnimStopVel -= tlhAnimStopKick * 0.32;
        tlhAnimStopVel *= 0.58;
        tlhAnimStopKick = clamp(tlhAnimStopKick, 0.0, 5.0);

        tlhAnimDrawKick += tlhAnimDrawVel;
        tlhAnimDrawVel -= tlhAnimDrawKick * 0.28;
        tlhAnimDrawVel *= 0.62;
        tlhAnimDrawKick = clamp(tlhAnimDrawKick, 0.0, 6.0);
    }

    int GetGameMode()
    {
        let cvar = CVar.FindCVar("tlh_gamemode");
        if (!cvar) return 0;
        int mode = cvar.GetInt();
        if (mode < 0) mode = 0;
        if (mode > 33) mode = 0;
        return mode;
    }

    void EnforceAmmoCap(String className, int cap)
    {
        let item = FindInventory(className);
        if (!item) return;

        item.MaxAmount = cap;
        if (item.Amount > cap) item.Amount = cap;
    }

    void GiveAllAmmoBurst(int amount)
    {
        GiveInventory("Clip", amount);
        GiveInventory("Shell", amount);
        GiveInventory("RocketAmmo", amount);
        GiveInventory("Cell", amount);
    }

    void ApplyGameModeTick(int mode, bool onGround, int bt)
    {
        // Armor reference is local to this function.
        // The previous build incorrectly referenced the Tick() local `arm`.
        let arm = BasicArmor(FindInventory("BasicArmor"));

        // 0 - Tactical Standard
        if (mode == 0)
        {
            // Default tactical cap: TLH_MAX_HEALTH HP / TLH_MAX_ARMOR armor. No recurring modifiers.
        }
        // 1 - Classic Doom
        else if (mode == 1)
        {
            if (health > 100) health = 100;
            if (arm && arm.Amount > 100) arm.Amount = 100;
        }
        // 2 - Hardcore
        else if (mode == 2)
        {
            if (health > 100) health = 100;
            if (arm && arm.Amount > 100) arm.Amount = 100;
        }
        // 3 - Glass Cannon
        else if (mode == 3)
        {
            if (health > 35) health = 35;
            if (arm && arm.Amount > 35) arm.Amount = 35;
        }
        // 4 - Bulletstorm
        else if (mode == 4)
        {
            if ((level.maptime % 10) == 0)
                GiveAllAmmoBurst(6);
        }
        // 5 - Infinite Ammo
        else if (mode == 5)
        {
            if ((level.maptime & 3) == 0)
                GiveAllAmmoBurst(24);
        }
        // 6 - Berserker
        else if (mode == 6)
        {
            if (!FindInventory("PowerStrength"))
                GiveInventory("PowerStrength", 1);
        }
        // 7 - Low Gravity
        else if (mode == 7)
        {
            if (!onGround) Vel.Z += 0.35;
        }
        // 8 - High Gravity
        else if (mode == 8)
        {
            if (!onGround) Vel.Z -= 0.30;
        }
        // 9 - Speedrun
        else if (mode == 9)
        {
            if (bt & BT_FORWARD) Thrust(0.90, angle);
            if (bt & BT_BACK) Thrust(0.45, angle + 180);
            if (bt & BT_MOVELEFT) Thrust(0.65, angle - 90);
            if (bt & BT_MOVERIGHT) Thrust(0.65, angle + 90);
            if (slideCooldown > 0) slideCooldown--;
        }
        // 10 - Pistol Start is applied by InitializeGameModeLocal().
        else if (mode == 10)
        {
        }
        // 11 - Shotgun Start is applied by InitializeGameModeLocal().
        else if (mode == 11)
        {
        }
        // 12 - M4A1 Start is applied by InitializeGameModeLocal().
        else if (mode == 12)
        {
        }
        // 13 - M60 Start is applied by InitializeGameModeLocal().
        else if (mode == 13)
        {
        }
        // 14 - Random Arsenal is applied by InitializeGameModeLocal().
        else if (mode == 14)
        {
        }
        // 15 - Horde
        // Periodically inserts enemies from the expanded, valid actor roster.
        else if (mode == 15)
        {
            hordeTimer++;
            if (hordeTimer >= 175)
            {
                hordeTimer = 0;
                SpawnModeEnemy(random(1, 2), false);
            }
        }
        // 16 - Arena
        else if (mode == 16)
        {
            arenaTimer++;
            if (arenaTimer >= 110)
            {
                arenaTimer = 0;
                SpawnModeEnemy(random(1, 2), true);
            }
        }
        // 17 - Survival
        else if (mode == 17)
        {
            survivalTimer++;
            if (survivalTimer >= 25)
            {
                survivalTimer = 0;
                if (health > 0 && health < TLH_MAX_HEALTH) health++;
            }
        }
        // 18 - No Powerups is enforced by TacticalHUDHandler when things spawn.
        else if (mode == 18)
        {
        }
        // 19 - SSG Lockdown is enforced by TacticalHUDHandler and startup.
        else if (mode == 19)
        {
        }
        // 20 - One Shot
        else if (mode == 20)
        {
            if (health > 1) health = 1;
            if (arm) arm.Amount = 0;
        }
        // 21 - Monster Frenzy is enforced when monsters spawn.
        else if (mode == 21)
        {
            // New and newly spawned monsters are boosted by the handler.
        }
        // 22 - Fragile Monsters is enforced when monsters spawn.
        else if (mode == 22)
        {
        }
        // 23 - Super Heavy is enforced when monsters spawn.
        else if (mode == 23)
        {
        }
        // 24 - Chaos
        else if (mode == 24)
        {
            if ((level.maptime & 31) == 0)
            {
                if (!onGround)
                    Vel.Z += FRandom(-0.8, 0.8);
                Thrust(FRandom(-0.08, 0.08), angle + random(0, 360));
            }
        }
        // 25 - No Armor
        else if (mode == 25)
        {
            if (arm) arm.Amount = 0;
        }
        // 26 - Ammo Scarcity is enforced when ammo pickups spawn.
        else if (mode == 26)
        {
        }
        // 27 - Pacifist is applied by InitializeGameModeLocal() and the spawn handler.
        else if (mode == 27)
        {
        }
        // 28 - Warzone
        else if (mode == 28)
        {
            if ((level.maptime & 127) == 0)
                GiveAllAmmoBurst(3);
            if (onGround && (bt & BT_FORWARD))
                Thrust(0.35, angle);
        }
        // 29 - Weapon Roulette
        else if (mode == 29)
        {
            rouletteTimer++;
            if (rouletteTimer >= 525)
            {
                rouletteTimer = 0;
                RandomlySelectOwnedWeapon();
            }
        }
        // 30 - Last Stand
        else if (mode == 30)
        {
            if (health > 25) health = 25;
            if (arm && arm.Amount > 25) arm.Amount = 25;
        }
        // 31 - Double Spawn
        else if (mode == 31)
        {
            hordeTimer++;
            if (hordeTimer >= 210)
            {
                hordeTimer = 0;
                SpawnModeEnemy(2, true);
            }
        }
        // 32 - Nightmare Lite
        else if (mode == 32)
        {
            survivalTimer++;
            if (survivalTimer >= 35)
            {
                survivalTimer = 0;
                if (health > 0 && health < 150) health++;
            }
        }
        // 33 - Training
        else if (mode == 33)
        {
            if (!FindInventory("PowerInvulnerable"))
                GiveInventory("PowerInvulnerable", 1);
            if ((level.maptime & 7) == 0)
                GiveAllAmmoBurst(12);
        }
    }

    void InitializeGameModeLocal(int mode)
    {
        // Remove persistent training/berserker effects when leaving those modes.
        // Without this cleanup, switching modes in the menu could leave powerups
        // active forever even after the ruleset changed.
        if (modeInitialized && previousGameMode != mode)
        {
            if (previousGameMode == 6 && mode != 6)
                RemoveOwnedItemLocal("PowerStrength");

            if (previousGameMode == 33 && mode != 33)
                RemoveOwnedItemLocal("PowerInvulnerable");
        }

        // Reset timers whenever a new mode/map is initialized.
        hordeTimer = 0;
        arenaTimer = 0;
        survivalTimer = 0;
        rouletteTimer = 0;

        if (mode == 10) // Pistol Start
        {
            RemoveAllWeaponsExceptLocal("DashFist");
            GiveModeWeaponLocal("RecoilPistol");
            GiveInventory("Clip", 50);
        }
        else if (mode == 11) // Shotgun Start
        {
            RemoveAllWeaponsExceptLocal("DashFist");
            GiveModeWeaponLocal("RecoilShotgun");
            GiveInventory("Shell", 20);
        }
        else if (mode == 12) // M4A1 Start
        {
            RemoveAllWeaponsExceptLocal("DashFist");
            GiveModeWeaponLocal("TacticalM4A1");
            GiveInventory("Clip", 120);
        }
        else if (mode == 13) // M60 Start
        {
            RemoveAllWeaponsExceptLocal("DashFist");
            GiveModeWeaponLocal("M60MachineGun");
            GiveInventory("Clip", 140);
        }
        else if (mode == 14) // Random Arsenal
        {
            RemoveAllWeaponsExceptLocal("DashFist");
            int r = random(0, 7);
            if (r == 0) GiveModeWeaponLocal("RecoilPistol");
            else if (r == 1) GiveModeWeaponLocal("OfficerVulkanPistol");
            else if (r == 2) GiveModeWeaponLocal("RecoilShotgun");
            else if (r == 3) GiveModeWeaponLocal("TacticalM4A1");
            else if (r == 4) GiveModeWeaponLocal("HeavyChaingun");
            else if (r == 5) GiveModeWeaponLocal("M60MachineGun");
            else if (r == 6) GiveModeWeaponLocal("RecoilRocketLauncher");
            else GiveModeWeaponLocal("AMR99RailRifle");

            GiveAllAmmoBurst(20);
        }
        else if (mode == 19) // SSG Lockdown
        {
            RemoveAllWeaponsExceptLocal("DashFist");
            GiveModeWeaponLocal("FastRecoilSSG");
            GiveInventory("Shell", 30);
        }
        else if (mode == 20) // One Shot
        {
            health = 1;
        }
        else if (mode == 25) // No Armor
        {
            let armor = FindInventory("BasicArmor");
            if (armor)
                BasicArmor(armor).Amount = 0;
        }
        else if (mode == 27) // Pacifist
        {
            RemoveAllWeaponsExceptLocal("DashFist");
            GiveModeWeaponLocal("DashFist");
        }
        else if (mode == 30) // Last Stand
        {
            health = 25;
        }
        else if (mode == 33) // Training
        {
            if (!FindInventory("PowerInvulnerable"))
                GiveInventory("PowerInvulnerable", 1);
            GiveAllAmmoBurst(40);
        }
    }

    void RemoveOwnedItemLocal(String cls)
    {
        Inventory item = FindInventory(cls);
        while (item != null)
        {
            Inventory nextItem = item.Inv;
            RemoveInventory(item);
            item.Destroy();
            item = nextItem;
        }
    }

    void RemoveAllWeaponsExceptLocal(String keep)
    {
        Inventory item = Inv;
        while (item != null)
        {
            Inventory nextItem = item.Inv;
            if (item is "Weapon")
            {
                String cls = item.GetClassName();
                if (cls != keep)
                {
                    RemoveInventory(item);
                    item.Destroy();
                }
            }
            item = nextItem;
        }
    }

    void GiveModeWeaponLocal(String cls)
    {
        if (!FindInventory(cls))
            GiveInventory(cls, 1);

        let wep = Weapon(FindInventory(cls));
        if (wep && player)
            player.PendingWeapon = wep;
    }

    void SpawnModeEnemy(int amount, bool elite)
    {
        for (int i = 0; i < amount; i++)
        {
            String cls;
            int r = random(0, elite ? 24 : 20);

            if (r == 0) cls = "DoomImp";
            else if (r == 1) cls = "Demon";
            else if (r == 2) cls = "ShotgunGuy";
            else if (r == 3) cls = "ChaingunGuy";
            else if (r == 4) cls = "HellKnight";
            else if (r == 5) cls = "Revenant";
            else if (r == 6) cls = "Fatso";
            else if (r == 7) cls = "TLH_AssaultImp";
            else if (r == 8) cls = "TLH_HeavyShotgunGuy";
            else if (r == 9) cls = "TLH_BerserkerDemon";
            else if (r == 10) cls = "TLH_RavagerRevenant";
            else if (r == 11) cls = "TLH_HeavyMancubus";
            else if (r == 12) cls = "TLH_CombatBaron";
            else if (r == 13) cls = "TLH_AssaultArachnotron";
            else if (r == 14) cls = "TLH_TacticalMancubus";
            else if (r == 15) cls = "TLH_SiegeArachnotron";
            else if (r == 16) cls = "TLH_BloodCacodemon";
            else if (r == 17) cls = "TLH_ArmoredHellKnight";
            else if (r == 18) cls = "TLH_DevastatorRevenant";
            else if (r == 19) cls = "TLH_VoidCacodemon";
            else if (r == 20) cls = "TLH_StalkerImp";
            else if (r == 21) cls = "TLH_BreacherShotgunner";
            else if (r == 22) cls = "TLH_RazorDemon";
            else if (r == 23) cls = "TLH_HunterRevenant";
            else cls = "TLH_AssaultBaron";

            double a = FRandom(0, 360);
            double d = FRandom(192, 288);
            Vector3 spawnPos = Pos + (cos(a) * d, sin(a) * d, 0);
            Actor mo = Spawn(cls, spawnPos);

            if (mo && elite)
            {
                mo.Health = int(double(mo.Health) * 1.35);
                mo.Speed = mo.Speed * 1.20;
                if (mo.Speed > 24) mo.Speed = 24;
            }
        }
    }

    void RandomlySelectOwnedWeapon()
    {
        int count = 0;

        if (FindInventory("RecoilPistol")) count++;
        if (FindInventory("ServiceRevolver")) count++;
        if (FindInventory("OfficerVulkanPistol")) count++;
        if (FindInventory("RecoilShotgun")) count++;
        if (FindInventory("StreetSweeperShotgun")) count++;
        if (FindInventory("FastRecoilSSG")) count++;
        if (FindInventory("TacticalM4A1")) count++;
        if (FindInventory("HeavyChaingun")) count++;
        if (FindInventory("M60MachineGun")) count++;
        if (FindInventory("RecoilRocketLauncher")) count++;
        if (FindInventory("RecoilPlasmaRifle")) count++;
        if (FindInventory("AMR99RailRifle")) count++;

        if (count <= 0) return;

        int pick = random(1, count);
        String selected = "";

        if (FindInventory("RecoilPistol"))
        {
            if (pick == 1) selected = "RecoilPistol";
            else pick--;
        }
        if (selected == "" && FindInventory("ServiceRevolver"))
        {
            if (pick == 1) selected = "ServiceRevolver";
            else pick--;
        }
        if (selected == "" && FindInventory("OfficerVulkanPistol"))
        {
            if (pick == 1) selected = "OfficerVulkanPistol";
            else pick--;
        }
        if (selected == "" && FindInventory("RecoilShotgun"))
        {
            if (pick == 1) selected = "RecoilShotgun";
            else pick--;
        }
        if (selected == "" && FindInventory("StreetSweeperShotgun"))
        {
            if (pick == 1) selected = "StreetSweeperShotgun";
            else pick--;
        }
        if (selected == "" && FindInventory("FastRecoilSSG"))
        {
            if (pick == 1) selected = "FastRecoilSSG";
            else pick--;
        }
        if (selected == "" && FindInventory("TacticalM4A1"))
        {
            if (pick == 1) selected = "TacticalM4A1";
            else pick--;
        }
        if (selected == "" && FindInventory("HeavyChaingun"))
        {
            if (pick == 1) selected = "HeavyChaingun";
            else pick--;
        }
        if (selected == "" && FindInventory("M60MachineGun"))
        {
            if (pick == 1) selected = "M60MachineGun";
            else pick--;
        }
        if (selected == "" && FindInventory("RecoilRocketLauncher"))
        {
            if (pick == 1) selected = "RecoilRocketLauncher";
            else pick--;
        }
        if (selected == "" && FindInventory("RecoilPlasmaRifle"))
        {
            if (pick == 1) selected = "RecoilPlasmaRifle";
            else pick--;
        }
        if (selected == "" && FindInventory("AMR99RailRifle"))
        {
            selected = "AMR99RailRifle";
        }

        if (selected != "")
        {
            let chosen = Weapon(FindInventory(selected));
            if (chosen) player.PendingWeapon = chosen;
        }
    }

    bool TryModeToggle()
    {
        if (akimboCooldown > 0 || akimboButtonHeld)
            return false;

        akimboButtonHeld = true;
        akimboCooldown = 14;
        return true;
    }

    bool TryAkimboToggle()
    {
        return TryModeToggle();
    }

}


// ============================================================================
// 5. SALUD, ARMADURA Y PERKS
// ============================================================================

class TacticalStimpack : Health replaces Stimpack
{
    Default
    {
        Inventory.Amount 15;
        Inventory.PickupMessage "Picked up a Tactical Stimpack.";
    }
    States
    {
    Spawn:
        STIM A -1;
        Stop;
    }
}

class TacticalMedikit : Health replaces Medikit
{
    Default
    {
        Inventory.Amount 35;
        Inventory.PickupMessage "Picked up a Trauma Kit.";
    }
    States
    {
    Spawn:
        MEDI A -1;
        Stop;
    }
}

class KevlarArmor : BasicArmorPickup replaces GreenArmor
{
    Default
    {
        Armor.SavePercent 50;
        Armor.SaveAmount 150;
        Inventory.PickupMessage "Picked up Kevlar Armor.";
    }
    States
    {
    Spawn:
        ARM1 AB 6 Bright;
        Loop;
    }
}

class HeavyAssaultArmor : BasicArmorPickup replaces BlueArmor
{
    Default
    {
        Armor.SavePercent 70;
        Armor.SaveAmount 300;
        Inventory.PickupMessage "Picked up Heavy Assault Armor.";
    }
    States
    {
    Spawn:
        ARM2 AB 6 Bright;
        Loop;
    }
}

// ============================================================================
// TLH POWERUP EFFECTS + GIVERS
// GZDoom 4.14.2-safe implementation. PowerupGiver has an internal EffectTics
// member and its native Use() copies that value to the spawned Powerup.
// We set the member in Use() and then call the native implementation.
// ============================================================================

class TLHAdrenalinePower : PowerSpeed
{
    Default
    {
        Powerup.Duration -60;
    }
}

class TLHJuggernautPower : PowerProtection
{
    Default
    {
        Powerup.Duration -60;
        DamageFactor "Normal", 0.3;
    }
}

class AdrenalinePerk : PowerupGiver
{
    Default
    {
        Inventory.PickupMessage "PERK ACQUIRED: Adrenaline Rush (Speed)!";
        Powerup.Type "TLHAdrenalinePower";
        +INVENTORY.AUTOACTIVATE;
    }

    override bool Use(bool pickup)
    {
        EffectTics = 60 * 35;
        return Super.Use(pickup);
    }

    States
    {
    Spawn:
        SOUL ABCDCB 6 Bright;
        Loop;
    }
}

class JuggernautPerk : PowerupGiver
{
    Default
    {
        Inventory.PickupMessage "PERK ACQUIRED: Juggernaut (Damage Resistance)!";
        Powerup.Type "TLHJuggernautPower";
        +INVENTORY.AUTOACTIVATE;
    }

    override bool Use(bool pickup)
    {
        EffectTics = 60 * 35;
        return Super.Use(pickup);
    }

    States
    {
    Spawn:
        MEGA ABCD 6 Bright;
        Loop;
    }
}

// ============================================================================
// TLH M12 COMPACT SMG
// New weapon built from DOOM II's native chaingun sprites (CHGG/CHGF/MGUN).
// Controlled automatic fire plus a three-round burst on alternate fire.
// ============================================================================
class TLHCompactSMG : Weapon
{
    Default
    {
        Weapon.SlotNumber 4;
        Weapon.SlotPriority 4.15;
        Weapon.SelectionOrder 415;
        Weapon.Kickback 55;
        Weapon.AmmoType1 "Clip";
        Weapon.AmmoGive1 30;
        Weapon.AmmoUse1 1;
        Inventory.PickupMessage "I found the M12 Compact SMG!";

        Translation
            "0:31=64:79",
            "32:47=112:127",
            "48:79=64:79",
            "80:111=80:95",
            "112:167=64:79",
            "168:191=112:127",
            "192:255=64:79";
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        ZHGG A 1 A_WeaponReady;
        Loop;

    Deselect:
        ZHGG A 1 A_Lower;
        Loop;

    Select:
        ZHGG A 1 A_Raise;
        Loop;

    Fire:
        ZHGG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) &&
                player.mo.CountInv("Clip") < 1)
                return ResolveState("Ready");
            return ResolveState("SMGFire");
        }
    SMGFire:
        ZHGG A 2
        {
            A_GunFlash();
            A_FireBullets(3.5, 2.0, 1, 5, "BulletPuff");
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_Recoil(1.2);
        }
        ZHGG B 1;
        ZHGG A 0 A_ReFire;
        Goto Ready;

    // Three-round burst. Each shot consumes one Clip; per-shot damage matches primary fire.
    AltFire:
        ZHGG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) &&
                player.mo.CountInv("Clip") < 3)
                return ResolveState("Ready");
            return ResolveState("SMGBurst");
        }
    SMGBurst:
        ZHGG A 2
        {
            A_GunFlash();
            A_FireBullets(5.0, 3.0, 1, 5, "BulletPuff");
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Recoil(2.0);
        }
        ZHGG B 1;
        ZHGG A 2
        {
            A_GunFlash();
            A_FireBullets(5.0, 3.0, 1, 5, "BulletPuff");
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Recoil(2.0);
        }
        ZHGG B 1;
        ZHGG A 2
        {
            A_GunFlash();
            A_FireBullets(5.0, 3.0, 1, 5, "BulletPuff");
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Recoil(2.0);
        }
        Goto Ready;

    Flash:
        ZHGF A 2 Bright A_Light1;
        ZHGF B 2 Bright A_Light2;
        Goto LightDone;

    Spawn:
        ZGUN A -1;
        Stop;
    }
}

class BerserkerPerk : CustomInventory replaces Berserk
{
    Default
    {
        +COUNTITEM
        Inventory.PickupMessage "PERK ACQUIRED: Berserker State!";
    }
    States
    {
    Spawn:
        PSTR A -1;
        Stop;
    Pickup:
        TNT1 A 0
        {
            A_GiveInventory("PowerStrength");
            A_GiveInventory("Health", 100);
        }
        Stop;
    }
}

// ============================================================================
// ============================================================================
// 6. TACTICAL / YARBIS HUD
// ============================================================================
// Rebuilt as a compact procedural helmet interior interface.
// No screen tint or full-screen color wash is used by this HUD.
// Geometry is drawn with lines and text; the Doomguy face is a normal bitmap.
// The classic Doomguy face is the only bitmap element and is drawn normally.
// Virtual design canvas: 640 x 360.
// ============================================================================

class TacticalHUDHandler : EventHandler
{
    // ------------------------------------------------------------------------
    // PLAY-CONTEXT TELEMETRY
    // ------------------------------------------------------------------------
    String hudMapName;
    String hudMapTitle;
    String hudModeName;
    String hudWeaponName;
    int hudMapTime;
    int hudPlayerHealth;
    int hudArmor;
    int hudArmorMax;
    int hudClip;
    int hudRevolverAmmo;
    int hudRevolverReserve;
    int hudShell;
    int hudRocket;
    int hudCell;
    int hudLiveEnemies;
    int hudTotalEnemies;
    int hudKills;
    double hudFOV;
    double hudMoveSpeed;
    double hudVerticalSpeed;
    double hudAltitude;
    bool hudOnGround;

    // Target-under-crosshair cache. Sampled in WorldTick, drawn in UI context.
    Actor tlhAimTarget;
    String tlhAimTargetName;
    int tlhAimTargetHealth;
    int tlhAimTargetMaxHealth;
    double tlhAimTargetDistance;
    bool tlhAimTargetVisible;

    // ------------------------------------------------------------------------
    // INPUT OBSERVER
    // ------------------------------------------------------------------------
    transient ui bool tlhInputM3Down;
    transient ui String tlhInputLast;
    transient ui Array<String> tlhInputHistory;
    transient ui String tlhHUDDualBindName;

    // ------------------------------------------------------------------------
    // ANALYZER CACHE
    // ------------------------------------------------------------------------
    bool tlhVisorActive;
    int tlhVisorTime;
    String tlhVisorWeaponClass;
    transient Array<Actor> tlhVisorEnemies;
    transient Array<Actor> tlhVisorWeapons;
    transient Array<Actor> tlhVisorProjectiles;
    transient Array<String> tlhVisorEnemyNames;
    transient Array<String> tlhVisorWeaponNames;

    // ------------------------------------------------------------------------
    // SSG VFX CACHE
    // ------------------------------------------------------------------------
    bool tlhSSGVisible;
    double tlhSSGOffsetX;
    double tlhSSGOffsetY;
    double tlhSSGRoll;
    double tlhSSGRecoil;
    int tlhSSGPhase;
    bool tlhVisorPlayerDead;
    bool tlhHUDDualActive;

    // ------------------------------------------------------------------------
    // PLAY-CONTEXT WEAPON HUD CACHE
    // ------------------------------------------------------------------------
    // UI code must not call play-scoped Weapon state helpers. Sample the real
    // weapon PSprite here and let the overlay consume only cached data.
    TextureID hudWeaponTexture;
    bool hudWeaponTextureValid;
    bool hudWeaponFlip;
    Vector2 hudWeaponStateScale;
    int hudWeaponTranslation;
    String hudWeaponTextureClass;

    // ------------------------------------------------------------------------
    // CLASSIC DOOMGUY FACE STATE
    // ------------------------------------------------------------------------
    // Mirrors the original Doom facial system: health band, idle glances,
    // attack-direction turns, pain/ouch, weapon grin, teeth-grit, god eyes
    // and death. The face itself remains an unmodified classic bitmap.
    String tlhFaceName;
    String tlhFacePreviousWeapon;
    int tlhFacePreviousHealth;
    int tlhFacePriority;
    int tlhFaceTimer;
    int tlhFaceAttackHold;
    int tlhFaceHealthBand;
    int tlhFaceGaze;

    override void OnRegister(){
        // Observe keyboard and mouse input without consuming it.
        // IsUiProcessor stays false so player movement/camera input continues
        // to the normal GZDoom responder. RequireMouse lets the register see M3.
        SetOrder(0);
        IsUiProcessor = false;
        RequireMouse = true;
        // The HUD bind-name field is UI-scoped and must only be written
        // from UI context. RenderOverlay falls back to G until InputProcess
        // observes the configured binding.
    }


    override void WorldThingSpawned(WorldEvent e){
        if (!e.Thing) return;

        // World pickups must use their original sprite palette. The class
        // defaults still carry the custom first-person translation.
        let worldWeapon = Weapon(e.Thing);
        if (worldWeapon && !worldWeapon.Owner)
            worldWeapon.Translation = 0;

        if (e.Thing is "HellfireProjector")
            e.Thing.Scale = (0.56, 0.56);

        let modeCvar = CVar.FindCVar("tlh_gamemode");
        int gameMode = modeCvar ? modeCvar.GetInt() : 0;

        if (gameMode == 18 &&
            (e.Thing is "PowerupGiver" ||
             e.Thing is "BerserkerPerk" ||
             e.Thing is "Megasphere" ||
             e.Thing is "Soulsphere" ||
             e.Thing is "InvulnerabilitySphere" ||
             e.Thing is "BlurSphere" ||
             e.Thing is "RadSuit" ||
             e.Thing is "Allmap" ||
             e.Thing is "Infrared"))
        {
            e.Thing.Destroy();
            return;
        }

        if (gameMode == 26 && (e.Thing is "Ammo"))
        {
            if (random(1, 100) <= 45)
            {
                e.Thing.Destroy();
                return;
            }
        }

        if ((gameMode == 19 || gameMode == 27) && e.Thing is "Weapon" && !(e.Thing is "DashFist") && !(e.Thing is "HookChainsaw") && !(e.Thing is "FastRecoilSSG" && gameMode == 19))
        {
            e.Thing.Destroy();
            return;
        }

        if (e.Thing.bISMONSTER)
        {
            if (gameMode == 21)
            {
                e.Thing.Health = int(double(e.Thing.Health) * 1.35);
                e.Thing.Speed = e.Thing.Speed * 1.35;
            }
            else if (gameMode == 22)
            {
                e.Thing.Health = max(1, int(double(e.Thing.Health) * 0.55));
                e.Thing.Speed = e.Thing.Speed * 1.10;
            }
            else if (gameMode == 23)
            {
                e.Thing.Health = int(double(e.Thing.Health) * 2.0);
                e.Thing.Speed = e.Thing.Speed * 0.85;
            }
            else if (gameMode == 24)
            {
                e.Thing.Health = max(1, int(double(e.Thing.Health) * FRandom(0.65, 1.65)));
                e.Thing.Speed = e.Thing.Speed * FRandom(0.80, 1.60);
            }
            else if (gameMode == 28)
            {
                e.Thing.Health = int(double(e.Thing.Health) * 1.25);
                e.Thing.Speed = e.Thing.Speed * 1.25;
            }
            else if (gameMode == 32)
            {
                e.Thing.Health = int(double(e.Thing.Health) * 1.15);
                e.Thing.Speed = e.Thing.Speed * 1.15;
            }
            else if (gameMode == 2)
            {
                e.Thing.Health = int(double(e.Thing.Health) * 1.50);
            }
        }

        let cvar = CVar.FindCVar("tlh_ssg_only");
        if (cvar && cvar.GetBool())
        {
            let inv = Inventory(e.Thing);
            if (inv && !inv.Owner && e.Thing is "Weapon" && !(e.Thing is "FastRecoilSSG") && !(e.Thing is "DashFist") && !(e.Thing is "HookChainsaw"))
            {
                e.Thing.Destroy();
            }
            return;
        }

        bool isFirstMap = (level.levelnum == 1 || level.mapname ~== "MAP01" || level.mapname ~== "E1M1");
        if (isFirstMap) return;

        // Pistol normal -> Officer's Vulkan (5% world pickup chance).
        if (e.Thing is "RecoilPistol")
        {
            let inv = Inventory(e.Thing);
            if (inv && !inv.Owner && random(1, 100) <= 5)
            {
                Vector3 spawnPos = e.Thing.Pos;
                uint spawnFlags = e.Thing.SpawnFlags;
                e.Thing.Destroy();

                let wep = Actor.Spawn("OfficerVulkanPistol", spawnPos);
                if (wep)
                {
                    wep.SpawnFlags = spawnFlags;
                    wep.Vel = (FRandom(-2, 2), FRandom(-2, 2), FRandom(2, 4));
                }
            }
        }

                // Backpack rarity:
        // 15% -> Military Backpack
        //  2% -> Loadout Backpack
        // The rolls are mutually exclusive, so Loadout is deliberately much
        // rarer than the Military variant while remaining discoverable.
        if (e.Thing is "Backpack")
        {
            let inv = Inventory(e.Thing);
            if (inv && !inv.Owner)
            {
                int roll = random(1, 100);
                if (roll <= 2 || roll <= 17)
                {
                    Vector3 spawnPos = e.Thing.Pos;
                    uint spawnFlags = e.Thing.SpawnFlags;
                    e.Thing.Destroy();

                    String backpackClass = (roll <= 2) ? "LoadoutBackpack" : "MilitaryBackpack";
                    let bp = Actor.Spawn(backpackClass, spawnPos);
                    if (bp)
                    {
                        bp.SpawnFlags = spawnFlags;
                        bp.Vel = (FRandom(-2, 2), FRandom(-2, 2), FRandom(2, 4));
                    }
                }
            }
        }
    }


    override void PlayerEntered(PlayerEvent e){
        let cvar = CVar.FindCVar("tlh_ssg_only");
        if (!cvar || !cvar.GetBool()) return;

        let p = players[e.PlayerNumber].mo;
        if (!p) return;

        Inventory item = p.Inv;
        while (item != null)
        {
            Inventory nextItem = item.Inv;
            if (item is "Weapon" && !(item is "DashFist") && !(item is "HookChainsaw") && !(item is "FastRecoilSSG"))
            {
                p.RemoveInventory(item);
                item.Destroy();
            }
            item = nextItem;
        }

        double ang = p.Angle;
        Vector3 basePos = p.Pos + (cos(ang) * 40, sin(ang) * 40, 8);

        Actor.Spawn("FastRecoilSSG", basePos);
        Actor.Spawn("Backpack", basePos + (32, 0, 0));
        Actor.Spawn("Backpack", basePos + (-32, 0, 0));
        Actor.Spawn("Backpack", basePos + (0, 32, 0));

        // Game-mode loadouts are initialized by TacticalPlayer on map start.
    }


    String GetGameModeName(int mode){
        if (mode == 1) return "CLASSIC DOOM";
        if (mode == 2) return "HARDCORE";
        if (mode == 3) return "GLASS CANNON";
        if (mode == 4) return "BULLETSTORM";
        if (mode == 5) return "INFINITE AMMO";
        if (mode == 6) return "BERSERKER";
        if (mode == 7) return "LOW GRAVITY";
        if (mode == 8) return "HIGH GRAVITY";
        if (mode == 9) return "SPEEDRUN";
        if (mode == 10) return "PISTOL START";
        if (mode == 11) return "SHOTGUN START";
        if (mode == 12) return "M4A1 START";
        if (mode == 13) return "M60 START";
        if (mode == 14) return "RANDOM ARSENAL";
        if (mode == 15) return "HORDE";
        if (mode == 16) return "ARENA";
        if (mode == 17) return "SURVIVAL";
        if (mode == 18) return "NO POWERUPS";
        if (mode == 19) return "SSG LOCKDOWN";
        if (mode == 20) return "ONE SHOT";
        if (mode == 21) return "MONSTER FRENZY";
        if (mode == 22) return "FRAGILE MONSTERS";
        if (mode == 23) return "SUPER HEAVY";
        if (mode == 24) return "CHAOS";
        if (mode == 25) return "NO ARMOR";
        if (mode == 26) return "AMMO SCARCITY";
        if (mode == 27) return "PACIFIST";
        if (mode == 28) return "WARZONE";
        if (mode == 29) return "WEAPON ROULETTE";
        if (mode == 30) return "LAST STAND";
        if (mode == 31) return "DOUBLE SPAWN";
        if (mode == 32) return "NIGHTMARE LITE";
        if (mode == 33) return "TRAINING";
        return "TACTICAL STANDARD";
    }


    void RemoveAllWeaponsExcept(Actor p, String keepA, String keepB){
        Inventory item = p.Inv;
        while (item != null)
        {
            Inventory nextItem = item.Inv;
            if (item is "Weapon")
            {
                String cls = item.GetClassName();
                if (cls != keepA && cls != keepB)
                {
                    p.RemoveInventory(item);
                    item.Destroy();
                }
            }
            item = nextItem;
        }
    }


    void GiveModeWeapon(Actor p, int playerNum, String cls){
        if (!p.FindInventory(cls)) p.GiveInventory(cls, 1);
        let wep = Weapon(p.FindInventory(cls));
        if (wep) players[playerNum].PendingWeapon = wep;
    }


    override bool InputProcess(InputEvent e){
        if (e.Type == InputEvent.Type_KeyDown ||
            e.Type == InputEvent.Type_KeyUp)
        {
            String keyName = e.KeyString;

            if (keyName == "")
                keyName = String.Format("KEY_%d", int(e.KeyScan));

            String binding = Bindings.GetBinding(e.KeyScan);

            if (binding ~== "TLH_DualWield" ||
                binding ~== "netevent tlh_dualwield")
            {
                tlhHUDDualBindName = keyName;
            }

            if (binding != "")
                keyName = keyName .. " <" .. binding .. ">";

            if (e.Type == InputEvent.Type_KeyDown)
            {
                tlhInputLast = "DOWN " .. keyName;
                tlhInputHistory.Push(tlhInputLast);
            }
            else
            {
                tlhInputLast = "UP   " .. keyName;
                tlhInputHistory.Push(tlhInputLast);
            }

            if (tlhInputHistory.Size() > 32)
                tlhInputHistory.Delete(0);

            // M3 is not represented by a BT_* gameplay button, so keep its
            // actual physical key state here. All other live states below use
            // PlayerInfo.cmd.buttons and therefore remain synchronized with
            // gameplay input.
            if (e.KeyScan == InputEvent.KEY_MOUSE3 ||
                keyName ~== "MOUSE3" ||
                keyName ~== "MOUSE 3")
            {
                tlhInputM3Down = (e.Type == InputEvent.Type_KeyDown);
            }
        }

        // Never consume input. GZDoom continues dispatching the event to the
        // actual game responder after this observer returns false.
        return false;
    }


    override void NetworkProcess(ConsoleEvent e){
        if (e.Name ~== "tlh_dualwield")
        {
            int playerNum = e.Player;

            if (playerNum >= 0 && playerNum < MAXPLAYERS)
            {
                let p = players[playerNum].mo;
                if (p && p.player)
                {
                    let tp = TacticalPlayer(p);
                    if (tp)
                        tp.ToggleTLHDualWield();
                }
            }
        }
    }


    int GetTLHFaceHealthBand(Actor p)
    {
        if (!p || p.Health <= 0) return 4;

        int mode = 0;
        let c = CVar.FindCVar("tlh_gamemode");
        if (c) mode = c.GetInt();

        int faceMax = 600;
        if (mode == 1 || mode == 2) faceMax = 100;
        else if (mode == 3) faceMax = 35;
        else if (mode == 20) faceMax = 1;
        else if (mode == 30) faceMax = 25;
        else if (mode == 32) faceMax = 150;

        double ratio = double(max(0, p.Health)) / double(max(1, faceMax));
        if (ratio >= 0.80) return 0;
        if (ratio >= 0.60) return 1;
        if (ratio >= 0.40) return 2;
        if (ratio >= 0.20) return 3;
        return 4;
    }

    void SetTLHFace(String name, int priority, int timer)
    {
        if (priority >= tlhFacePriority || tlhFaceTimer <= 0)
        {
            tlhFaceName = name;
            tlhFacePriority = priority;
            tlhFaceTimer = timer;
        }
    }

    void UpdateTLHDoomguyFace(Actor p)
    {
        if (!p || !p.player)
        {
            tlhFaceName = "STFST00";
            return;
        }

        int band = GetTLHFaceHealthBand(p);
        tlhFaceHealthBand = band;

        if (tlhFacePreviousHealth == 0 && p.Health > 0)
        {
            tlhFacePriority = 0;
            tlhFaceTimer = 0;
        }

        if (p.Health <= 0 || p.player.playerstate == PST_DEAD)
        {
            SetTLHFace("STFDEAD0", 10, 2);
            tlhFacePreviousHealth = p.Health;
            return;
        }

        if (p.FindInventory("PowerInvulnerable"))
        {
            SetTLHFace("STFGOD0", 9, 2);
        }

        int currentHealth = p.Health;
        if (tlhFacePreviousHealth > currentHealth)
        {
            int loss = tlhFacePreviousHealth - currentHealth;
            Actor attacker = p.player.attacker;

            if (loss >= 20)
            {
                SetTLHFace(String.Format("STFOUCH%d", band), 8, 35);
            }
            else if (attacker && attacker != p)
            {
                double dx = attacker.Pos.X - p.Pos.X;
                double dy = attacker.Pos.Y - p.Pos.Y;
                double facingX = cos(p.Angle);
                double facingY = sin(p.Angle);
                double frontDot = facingX * dx + facingY * dy;
                double side = facingX * dy - facingY * dx;

                // Front-on threat: clenched-teeth/rampage face.
                if (frontDot > 0 && abs(side) <= frontDot)
                {
                    SetTLHFace(String.Format("STFKILL%d", band), 7, 35);
                }
                else if (side > 0)
                {
                    // Attack from screen-left: look left toward it.
                    SetTLHFace(String.Format("STFTL%d0", band), 7, 35);
                }
                else
                {
                    // Attack from screen-right: look right toward it.
                    SetTLHFace(String.Format("STFTR%d0", band), 7, 35);
                }
            }
            else
            {
                SetTLHFace(String.Format("STFKILL%d", band), 6, 28);
            }
        }

        String readyWeaponClass = "";
        if (p.player.ReadyWeapon)
            readyWeaponClass = p.player.ReadyWeapon.GetClassName();

        // A newly equipped weapon produces the classic wicked grin. This is
        // intentionally driven by the weapon transition, without touching
        // the weapon sprite itself.
        if (tlhFacePreviousWeapon != "" &&
            readyWeaponClass != "" &&
            readyWeaponClass != tlhFacePreviousWeapon)
        {
            SetTLHFace(String.Format("STFEVL%d", band), 6, 70);
        }
        tlhFacePreviousWeapon = readyWeaponClass;

        int bt = p.player.cmd.buttons;
        if (bt & BT_ATTACK)
            tlhFaceAttackHold++;
        else
            tlhFaceAttackHold = 0;

        // Long continuous fire: teeth clenched, exactly the classic Doom cue.
        if (tlhFaceAttackHold == 70)
            SetTLHFace(String.Format("STFKILL%d", band), 5, 35);

        if (tlhFaceTimer > 0)
            tlhFaceTimer--;

        // When an event expires, resume normal wary glances. The sequence is
        // deliberately non-monotonic to avoid looking robotic.
        if (tlhFaceTimer <= 0)
        {
            tlhFacePriority = 0;
            int idlePhase = (level.time / 18) % 6;
            if (idlePhase == 0 || idlePhase == 3)
                tlhFaceGaze = 0;
            else if (idlePhase == 1 || idlePhase == 4)
                tlhFaceGaze = 1;
            else
                tlhFaceGaze = 2;

            tlhFaceName = String.Format("STFST%d%d", band, tlhFaceGaze);
        }

        tlhFacePreviousHealth = currentHealth;
    }

    override void WorldTick(){
        // Defensive guard: the HUD must not sample level state outside an
        // initialized map. This prevents a script-side null access, not native
        // engine crashes or faults originating outside ZScript.
        if (!level) return;

        // --------------------------------------------------------------------
        // Sample all HUD data in play context.
        // ThinkerIterator is used for the live hostile count, so dynamically
        // spawned monsters also appear in the counter instead of relying only
        // on the map's static total_monsters value.
        // --------------------------------------------------------------------
        hudMapName = level.MapName;
        hudMapTitle = level.LevelName;
        hudMapTime = level.maptime;
        hudTotalEnemies = level.total_monsters;
        hudKills = level.killed_monsters;
        hudLiveEnemies = 0;
        hudPlayerHealth = 0;
        hudArmor = 0;
        hudArmorMax = 0;
        hudClip = 0;
        hudRevolverAmmo = 0;
        hudRevolverReserve = 0;
        hudShell = 0;
        hudRocket = 0;
        hudCell = 0;
        hudFOV = 90.0;
        hudMoveSpeed = 0.0;
        hudVerticalSpeed = 0.0;
        hudAltitude = 0.0;
        hudOnGround = true;
        hudWeaponName = "NONE";
        hudModeName = "TACTICAL STANDARD";

        // Rebuild the helmet analyzer cache in play context.
        tlhVisorActive = false;
        tlhVisorTime = level.time;
        tlhVisorWeaponClass = "";
        tlhVisorEnemies.Clear();
        tlhVisorWeapons.Clear();
        tlhVisorProjectiles.Clear();
        tlhVisorEnemyNames.Clear();
        tlhVisorWeaponNames.Clear();
        tlhSSGVisible = false;
        tlhSSGOffsetX = 0.0;
        tlhSSGOffsetY = 0.0;
        tlhSSGRoll = 0.0;
        tlhSSGRecoil = 0.0;
        tlhSSGPhase = 0;
        tlhVisorPlayerDead = false;
        tlhHUDDualActive = false;

        if (tlhFaceName == "")
            tlhFaceName = "STFST00";

        if (level.maptime == 0)
        {
            tlhFacePreviousHealth = 0;
            tlhFacePreviousWeapon = "";
            tlhFacePriority = 0;
            tlhFaceTimer = 0;
            tlhFaceAttackHold = 0;
            tlhFaceHealthBand = 0;
            tlhFaceGaze = 0;
        }

        if (consoleplayer < 0 || consoleplayer >= MAXPLAYERS)
        {
            hudWeaponTextureValid = false;
            hudWeaponTextureClass = "";
            return;
        }

        let p = players[consoleplayer].mo;
        if (!p || !p.player)
        {
            hudWeaponTextureValid = false;
            hudWeaponTextureClass = "";
            return;
        }

        // Avoid querying a live PSprite/State while GZDoom changes weapons.
        // The engine keeps drawing the real weapon; the HUD preview is disabled
        // because reading its transient state here is unnecessary and fragile.
        hudWeaponTextureValid = false;
        hudWeaponTextureClass = "";
        hudWeaponFlip = false;
        hudWeaponStateScale = (1.0, 1.0);
        hudWeaponTranslation = 0;

        UpdateTLHDoomguyFace(p);
        tlhVisorPlayerDead = (p.player.playerstate == PST_DEAD);
        tlhVisorActive = p.FindInventory("PowerInvulnerable") != null;

        let tpState = TacticalPlayer(p);
        if (tpState) tlhHUDDualActive = tpState.tlhDualWieldActive;

        hudPlayerHealth = max(0, p.Health);
        hudFOV = clamp(double(p.player.FOV), 20.0, 160.0);
        hudMoveSpeed = sqrt(p.Vel.X * p.Vel.X + p.Vel.Y * p.Vel.Y);
        hudVerticalSpeed = p.Vel.Z;
        hudAltitude = max(0.0, p.Pos.Z - p.floorz);
        hudOnGround = (p.Pos.Z <= p.floorz + 0.5);
        hudModeName = GetGameModeName(clamp(CVar.FindCVar("tlh_gamemode") ? CVar.FindCVar("tlh_gamemode").GetInt() : 0, 0, 33));
        UpdateAimTarget(p);

        let armor = BasicArmor(p.FindInventory("BasicArmor"));
        if (armor)
        {
            hudArmor = max(0, armor.Amount);
            hudArmorMax = max(0, armor.MaxAmount);
        }

        let ammo = p.FindInventory("Clip");
        if (ammo) hudClip = max(0, ammo.Amount);
        ammo = p.FindInventory("Shell");
        if (ammo) hudShell = max(0, ammo.Amount);
        ammo = p.FindInventory("RocketAmmo");
        if (ammo) hudRocket = max(0, ammo.Amount);
        ammo = p.FindInventory("Cell");
        if (ammo) hudCell = max(0, ammo.Amount);

        Weapon ready = p.player.ReadyWeapon;
        if (ready)
        {
            tlhVisorWeaponClass = ready.GetClassName();

            if (ready is "FastRecoilSSG")
            {
                tlhSSGPhase = level.time;
                let ssg = FastRecoilSSG(ready);
                if (ssg && ssg.akimboState == 0)
                {
                    tlhSSGVisible = true;

                    let tp = TacticalPlayer(p);
                    if (tp)
                    {
                        tlhSSGOffsetX = tp.tlhAnimSwayX + tp.tlhAnimInertiaX + tp.tlhAnimLookX * 0.60;
                        tlhSSGOffsetY = tp.tlhAnimSwayY + tp.tlhAnimInertiaY - tp.tlhAnimLookY * 0.35;
                        tlhSSGRoll = tp.tlhAnimWeaponKickSide * 1.1 + tp.tlhAnimSwayX * -0.4;
                        tlhSSGRecoil = tp.tlhAnimWeaponKick;
                    }
                }
            }

            hudWeaponName = ready.GetClassName();

            if (ready is "ServiceRevolver")
            {
                let revolver = ServiceRevolver(ready);
                if (revolver)
                {
                    hudRevolverAmmo = revolver.cylinderAmmo;
                    hudRevolverReserve = hudClip;
                }
            }

if (hudWeaponName == "RecoilPistol") hudWeaponName = "RECOIL PISTOL";
            else if (hudWeaponName == "ServiceRevolver") hudWeaponName = "SERVICE REVOLVER";
            else if (hudWeaponName == "OfficerVulkanPistol") hudWeaponName = "OFFICER VULKAN";
            else if (hudWeaponName == "RecoilShotgun") hudWeaponName = "COMBAT SHOTGUN";
            else if (hudWeaponName == "StreetSweeperShotgun") hudWeaponName = "STREET SWEEPER";
            else if (hudWeaponName == "FastRecoilSSG") hudWeaponName = "TACTICAL SSG";
            else if (hudWeaponName == "SemiAutoShotgun") hudWeaponName = "SEMI-AUTO SHOTGUN";
            else if (hudWeaponName == "TacticalM4A1") hudWeaponName = "TACTICAL M4A1";
            else if (hudWeaponName == "HeavyChaingun") hudWeaponName = "HEAVY CHAINGUN";
            else if (hudWeaponName == "TLHCompactSMG") hudWeaponName = "M12 COMPACT SMG";
            else if (hudWeaponName == "M60MachineGun") hudWeaponName = "M60 MACHINE GUN";
            else if (hudWeaponName == "RecoilRocketLauncher") hudWeaponName = "ROCKET LAUNCHER";
            else if (hudWeaponName == "RecoilPlasmaRifle") hudWeaponName = "PLASMA RIFLE";
            else if (hudWeaponName == "RecoilBFG9000") hudWeaponName = "BFG 9000";
            else if (hudWeaponName == "AMR99RailRifle") hudWeaponName = "AMR-99 GAUSS RIFLE";
            else if (hudWeaponName == "HellfireProjector") hudWeaponName = "HELLFIRE PROJECTOR";
            else if (hudWeaponName == "AirstrikeDesignator") hudWeaponName = "AIRSTRIKE DESIGNATOR";
            else if (hudWeaponName == "DashFist") hudWeaponName = "DASH FIST";
            else if (hudWeaponName == "HookChainsaw") hudWeaponName = "HOOK CHAINSAW";
        }

        ThinkerIterator it = ThinkerIterator.Create("Actor");
        Actor mo;
        while ((mo = Actor(it.Next())) != null)
        {
            if (mo.bIsMonster && mo.Health > 0)
            {
                hudLiveEnemies++;

                if (tlhVisorActive && tlhVisorEnemies.Size() < 32)
                {
                    double dx = mo.Pos.X - p.Pos.X;
                    double dy = mo.Pos.Y - p.Pos.Y;
                    double dz = mo.Pos.Z - p.Pos.Z;
                    double distanceSquared = dx * dx + dy * dy + dz * dz;

                    if (distanceSquared <= 1800.0 * 1800.0)
                    {
                        tlhVisorEnemies.Push(mo);
                        tlhVisorEnemyNames.Push(mo.GetClassName());
                    }
                }
            }

            if (tlhVisorActive && mo is "Weapon" && tlhVisorWeapons.Size() < 20)
            {
                Inventory weaponInv = Inventory(mo);
                if (weaponInv && weaponInv.Owner == null)
                {
                    double wdx = mo.Pos.X - p.Pos.X;
                    double wdy = mo.Pos.Y - p.Pos.Y;
                    double wdz = mo.Pos.Z - p.Pos.Z;
                    double weaponDistanceSquared = wdx * wdx + wdy * wdy + wdz * wdz;

                    if (weaponDistanceSquared <= 1600.0 * 1600.0)
                    {
                        tlhVisorWeapons.Push(mo);
                        tlhVisorWeaponNames.Push(mo.GetClassName());
                    }
                }
            }

            if (tlhVisorActive && mo.bMissile && tlhVisorProjectiles.Size() < 16)
            {
                double pdx = mo.Pos.X - p.Pos.X;
                double pdy = mo.Pos.Y - p.Pos.Y;
                double pdz = mo.Pos.Z - p.Pos.Z;
                double projectileDistanceSquared = pdx * pdx + pdy * pdy + pdz * pdz;
                double velocitySquared = mo.Vel.X * mo.Vel.X + mo.Vel.Y * mo.Vel.Y + mo.Vel.Z * mo.Vel.Z;

                if (projectileDistanceSquared <= 2000.0 * 2000.0 && velocitySquared > 1.0)
                    tlhVisorProjectiles.Push(mo);
            }
        }

    }


    // =========================================================================
    // AIM TARGET DATA
    // AimLineAttack follows GZDoom's 3D aim and current view height. This avoids
    // the old LineTrace path that was disabled after a native access violation.
    // =========================================================================
    String GetAimTargetName(Actor a)
    {
        if (!a) return "UNKNOWN";
        String cls = a.GetClassName();
        if (cls == "DoomImp" || cls == "TLH_AssaultImp" || cls == "TLH_BrutalImp" || cls == "TLH_StalkerImp") return "DOOM IMP";
        if (cls == "ZombieMan" || cls == "TacticalZombieMan") return "ZOMBIEMAN";
        if (cls == "ShotgunGuy" || cls == "TacticalShotgunGuy" || cls == "TLH_BreacherShotgunner") return "SHOTGUN GUY";
        if (cls == "ChaingunGuy" || cls == "TacticalChaingunGuy") return "CHAINGUNNER";
        if (cls == "Demon" || cls == "TLH_BerserkerDemon" || cls == "TLH_HeavyDemon" || cls == "TLH_RazorDemon") return "DEMON";
        if (cls == "HellKnight" || cls == "TLH_ArmoredHellKnight") return "HELL KNIGHT";
        if (cls == "BaronOfHell" || cls == "TLH_CombatBaron" || cls == "TLH_HellfireBaron" || cls == "TLH_ExecutionerBaron" || cls == "TLH_AssaultBaron") return "BARON OF HELL";
        if (cls == "Revenant" || cls == "TLH_RavagerRevenant" || cls == "TLH_SiegeRevenant" || cls == "TLH_DevastatorRevenant" || cls == "TLH_HunterRevenant") return "REVENANT";
        if (cls == "Fatso" || cls == "TLH_HeavyMancubus" || cls == "TLH_TacticalMancubus") return "MANCUBUS";
        if (cls == "Arachnotron" || cls == "TLH_AssaultArachnotron" || cls == "TLH_SiegeArachnotron") return "ARACHNOTRON";
        if (cls == "Cacodemon" || cls == "TLH_VanguardCacodemon" || cls == "TLH_BloodCacodemon" || cls == "TLH_VoidCacodemon") return "CACODEMON";
        return cls;
    }

    void UpdateAimTarget(Actor p)
    {
        tlhAimTarget = null;
        tlhAimTargetName = "";
        tlhAimTargetHealth = 0;
        tlhAimTargetMaxHealth = 0;
        tlhAimTargetDistance = 0.0;
        tlhAimTargetVisible = false;

        if (!p || !p.player || p.player.playerstate == PST_DEAD) return;

        FTranslatedLineTarget aim;
        p.AimLineAttack(p.Angle, 1024.0, aim, 0.0, ALF_CHECK3D);
        Actor target = aim.linetarget;
        if (!target || !target.bIsMonster || target.Health <= 0) return;
        if (!p.CheckSight(target)) return;

        tlhAimTarget = target;
        tlhAimTargetName = GetAimTargetName(target);
        tlhAimTargetHealth = max(0, target.Health);
        tlhAimTargetMaxHealth = max(1, target.GetSpawnHealth());
        tlhAimTargetDistance = p.Distance3D(target);
        tlhAimTargetVisible = true;
    }

    ui void DrawAimTargetLabel(Actor p, RenderEvent e)
    {
        Actor target = tlhAimTarget;
        if (!tlhAimTargetVisible || !target || target.Health <= 0) return;
        if (!p || !p.player) return;

        double fov = clamp(double(p.player.FOV), 20.0, 160.0);
        Vector3 headPos = target.Pos + (0, 0, target.Height + 5.0);
        double screenX, screenY, depth;

        // Reuse the HUD's native camera projection, including view pitch, roll,
        // aspect ratio and camera position. This keeps the label over the head
        // while the player jumps, crouches or looks up/down.
        if (!ProjectWorld(headPos, e, fov, screenX, screenY, depth)) return;
        if (depth < 1.0 || depth > 1024.0) return;
        if (screenX < 12.0 || screenX > 628.0 || screenY < 18.0 || screenY > 330.0) return;

        String hp = String.Format("%d / %d HP  |  %d u", tlhAimTargetHealth, tlhAimTargetMaxHealth, int(tlhAimTargetDistance));
        double width = max(double(SmallFont.StringWidth(tlhAimTargetName)), double(SmallFont.StringWidth(hp))) * 0.36;
        double left = clamp(screenX - width * 0.5, 6.0, 634.0 - width);
        double top = clamp(screenY - 21.0, 8.0, 320.0);
        Line(left - 4.0, top - 3.0, left + width + 4.0, top - 3.0, 0xAAB7B0, 180, 0.65);
        Text(tlhAimTargetName, left, top, Font.CR_WHITE, 0.36);
        Text(hp, left, top + 9.0, tlhAimTargetHealth <= tlhAimTargetMaxHealth * 0.25 ? Font.CR_RED : Font.CR_GREEN, 0.34);
    }

    // ========================================================================
    // PROCEDURAL DRAWING PRIMITIVES // YARBIS v2
    // ========================================================================

    ui double GetHUDResolutionScale()
    {
        // The HUD is authored on a 640x360 design grid, but must occupy the
        // entire active viewport. Use independent X/Y factors instead of
        // preserving 16:9 and leaving pillarbox/letterbox gaps.
        return max(0.01, min(double(Screen.GetWidth()) / 640.0,
                             double(Screen.GetHeight()) / 360.0));
    }

    ui Vector2 V(double x, double y)
    {
        double sx = double(Screen.GetWidth()) / 640.0;
        double sy = double(Screen.GetHeight()) / 360.0;
        return (x * sx, y * sy);
    }

    ui void Line(double x0, double y0, double x1, double y1, Color c, int a = 220, double w = 0.8)
    {
        Vector2 p0 = V(x0, y0);
        Vector2 p1 = V(x1, y1);
        double scale = GetHUDResolutionScale();
        Screen.DrawThickLine(p0.X, p0.Y, p1.X, p1.Y, max(0.55, w * scale), c, a);
    }

    ui void Text(String s, double x, double y, int c = Font.CR_WHITE, double scale = 0.40)
    {
        double sx = double(Screen.GetWidth()) / 640.0;
        double sy = double(Screen.GetHeight()) / 360.0;
        Vector2 p = V(x, y);
        Screen.DrawText(
            SmallFont,
            c,
            int(p.X), int(p.Y), s,
            DTA_VirtualWidth, Screen.GetWidth(),
            DTA_VirtualHeight, Screen.GetHeight(),
            DTA_ScaleX, scale * sx,
            DTA_ScaleY, scale * sy,
            DTA_Shadow, false
        );
    }

    ui void TextR(String s, double right, double y, int c = Font.CR_WHITE, double scale = 0.40)
    {
        int w = int(double(SmallFont.StringWidth(s)) * scale);
        Text(s, right - w, y, c, scale);
    }

    ui void TextC(String s, double center, double y, int c = Font.CR_WHITE, double scale = 0.40)
    {
        int w = int(double(SmallFont.StringWidth(s)) * scale);
        Text(s, center - w * 0.5, y, c, scale);
    }

    ui void Corner(double x, double y, double sx, double sy, Color c, int a = 210)
    {
        Line(x, y, x + 16.0 * sx, y, c, a, 1.0);
        Line(x, y, x, y + 10.0 * sy, c, a, 1.0);
        Line(x + 3.0 * sx, y + 3.0 * sy,
             x + 10.0 * sx, y + 3.0 * sy, c, a - 60, 0.55);
    }

    ui void Panel(double x, double y, double w, double h, Color c, int a = 145)
    {
        Line(x, y, x + w, y, c, a, 0.65);
        Line(x, y + h, x + w, y + h, c, a, 0.65);
        Line(x, y, x, y + h, c, a, 0.65);
        Line(x + w, y, x + w, y + h, c, a, 0.65);

        Line(x, y, x + 7, y, c, min(235, a + 60), 1.15);
        Line(x + w - 7, y + h, x + w, y + h, c, min(235, a + 60), 1.15);
    }

    ui void Notch(double x, double y, double dir, Color c, int a = 160)
    {
        Line(x, y, x + dir * 6, y, c, a, 0.75);
        Line(x + dir * 6, y, x + dir * 9, y + 3, c, a, 0.75);
        Line(x + dir * 9, y + 3, x + dir * 6, y + 6, c, a, 0.75);
    }

    ui void MicroTicks(double x, double y, int count, double step,
        double len, bool vertical, Color c, int a = 125)
    {
        for (int i = 0; i < count; i++)
        {
            double q = double(i) * step;
            if (vertical)
                Line(x, y + q, x + len, y + q, c, a, 0.55);
            else
                Line(x + q, y, x + q, y + len, c, a, 0.55);
        }
    }

    ui void SegBar(double x, double y, double width, int value, int maximum,
        int count, Color c)
    {
        if (maximum <= 0) return;
        double ratio = clamp(double(value) / double(maximum), 0.0, 1.0);
        int active = int(ratio * double(count) + 0.5);
        double gap = 1.4;
        double sw = (width - gap * double(count - 1)) / double(count);
        Color dim = 0x233A37;

        for (int i = 0; i < count; i++)
        {
            double x0 = x + double(i) * (sw + gap);
            Color use = (i < active) ? c : dim;
            Line(x0, y, x0 + sw, y, use,
                i < active ? 220 : 85,
                i < active ? 1.45 : 0.75);
        }
    }

    ui void Arc(double cx, double cy, double r, double a0, double a1,
        Color c, int alpha = 170, double w = 0.7)
    {
        int n = max(2, int(abs(a1 - a0) / 10.0));
        double pa = a0;
        double px = cx + cos(pa) * r;
        double py = cy + sin(pa) * r;
        for (int i = 1; i <= n; i++)
        {
            double t = double(i) / double(n);
            double a = a0 + (a1 - a0) * t;
            double nx = cx + cos(a) * r;
            double ny = cy + sin(a) * r;
            Line(px, py, nx, ny, c, alpha, w);
            px = nx;
            py = ny;
        }
    }

    // ========================================================================
    // CLASSIC DOOMGUY // SMALL BOTTOM-CENTER BIOMETRIC NODE
    // ========================================================================

    // ========================================================================
    // CLASSIC DOOMGUY // BOTTOM-CENTER BIO-LINK
    // ========================================================================

    ui TextureID FaceTexture()
    {
        String faceName = tlhFaceName;
        if (faceName == "")
            faceName = "STFST00";

        TextureID face = TexMan.CheckForTexture(faceName, TexMan.Type_MiscPatch);
        if (!face.IsValid())
            face = TexMan.CheckForTexture("STFST00", TexMan.Type_MiscPatch);
        return face;
    }

    ui void DrawDoomguyFace()
    {
        TextureID face = FaceTexture();
        if (!face.IsValid()) return;

        Screen.DrawTexture(
            face, false,
            310, 323,
            DTA_VirtualWidth, 640,
            DTA_VirtualHeight, 360,
            DTA_DestWidthF, 20.0,
            DTA_DestHeightF, 20.0,
            DTA_KeepRatio, true,
            DTA_Masked, true
        );
    }

    ui void DrawFaceNode()
    {
        Color frame = 0x586267;
        Color main = 0xB8C0C2;
        Color dim = 0x303639;
        Color steel = 0x737D80;
        Color warn = 0xB9A875;

        // Compact chin-camera housing. The portrait is intentionally tiny and
        // bottom-centred so it feels like a helmet sensor feed, not a status bar.
        Panel(280, 309, 80, 43, frame, 105);
        Line(292, 309, 310, 309, main, 175, 0.8);
        Line(330, 309, 348, 309, main, 175, 0.8);
        Line(286, 351, 302, 351, steel, 105, 0.55);
        Line(338, 351, 354, 351, steel, 105, 0.55);
        Line(280, 320, 286, 320, main, 125, 0.65);
        Line(354, 340, 360, 340, main, 125, 0.65);

        TextC("BIO-LINK", 320, 311, dim, 0.22);
        TextR(String.Format("HP %03d", max(0, hudPlayerHealth)), 305, 344,
            hudPlayerHealth < 40 ? Font.CR_RED : Font.CR_WHITE, 0.23);
        Text("FACE", 332, 344, dim, 0.21);

        DrawDoomguyFace();

        String faceState = "STABLE";
        int faceColor = main;
        if (hudPlayerHealth <= 0)
        {
            faceState = "DEAD";
            faceColor = Font.CR_RED;
        }
        else if (hudPlayerHealth < 40)
        {
            faceState = "PAIN";
            faceColor = warn;
        }
        else if (tlhVisorActive)
        {
            faceState = "GODMODE";
            faceColor = Font.CR_YELLOW;
        }

        TextC(faceState, 320, 352, faceColor, 0.20);
    }

    // ========================================================================
    // PERIMETER // DETAIL WITHOUT CENTRAL OBSTRUCTION
    // ========================================================================

    ui void DrawPerimeter()
    {
        Color shell = 0x353B3E;
        Color gasket = 0x454D51;
        Color main = 0xAEB7BA;
        Color dim = 0x272D30;
        Color steel = 0x737D80;

        // Top brow of the helmet. Broken segments imitate the inner edge of a
        // visor rather than a rectangular game HUD.
        Arc(320, 102, 300, 204, 336, shell, 170, 0.75);
        Arc(320, 102, 300, 24, 156, shell, 170, 0.75);
        Line(47, 48, 139, 35, gasket, 140, 0.65);
        Line(501, 35, 593, 48, gasket, 140, 0.65);
        Line(79, 43, 145, 33, steel, 100, 0.45);
        Line(495, 33, 561, 43, steel, 100, 0.45);

        // Temple rails / seal seams.
        Line(17, 72, 17, 252, shell, 145, 0.7);
        Line(623, 72, 623, 252, shell, 145, 0.7);
        Line(24, 84, 24, 241, dim, 115, 0.55);
        Line(616, 84, 616, 241, dim, 115, 0.55);

        // Cheek plates taper toward the chin. Most of the screen remains free.
        Line(18, 250, 74, 296, shell, 155, 0.75);
        Line(622, 250, 566, 296, shell, 155, 0.75);
        Line(29, 254, 82, 294, gasket, 100, 0.5);
        Line(611, 254, 558, 294, gasket, 100, 0.5);

        // Small bolts and diagnostic teeth.
        for (int i = 0; i < 6; i++)
        {
            double y = 94 + i * 27;
            Line(17, y, 28 + (i & 1) * 7, y, i == 2 ? main : dim,
                i == 2 ? 180 : 85, i == 2 ? 0.8 : 0.45);
            Line(612 - (i & 1) * 7, y, 623, y, i == 4 ? main : dim,
                i == 4 ? 180 : 85, i == 4 ? 0.8 : 0.45);
        }

        // Lower chin rail behind the tiny face camera.
        Line(79, 338, 257, 338, dim, 100, 0.55);
        Line(383, 338, 561, 338, dim, 100, 0.55);
        Line(112, 348, 259, 348, shell, 120, 0.55);
        Line(381, 348, 528, 348, shell, 120, 0.55);

        // Recessed visor-support panels. These are broken into sections so
        // the player still sees the world through a mostly open visor.
        Line(28, 155, 71, 147, gasket, 105, 0.5);
        Line(28, 160, 58, 155, dim, 80, 0.4);
        Line(612, 155, 569, 147, gasket, 105, 0.5);
        Line(612, 160, 582, 155, dim, 80, 0.4);
        Line(28, 194, 61, 200, dim, 80, 0.4);
        Line(612, 194, 579, 200, dim, 80, 0.4);

        // Four corner fasteners, intentionally asymmetrical like machined
        // helmet internals rather than symmetrical Doom UI brackets.
        Corner(12, 11, 1, 1, main, 190);
        Corner(628, 11, -1, 1, main, 190);
        Corner(12, 349, 1, -1, gasket, 150);
        Corner(628, 349, -1, -1, gasket, 150);

        Text("YRB / SHELL", 23, 246, dim, 0.22);
        TextR("HUD-SEAL", 617, 246, dim, 0.22);
        Text("03", 23, 259, steel, 0.22);
        TextR("04", 617, 259, steel, 0.22);
    }

    // ========================================================================
    // TOP HEADER // SYSTEM / MAP / COMMAND BUS
    // ========================================================================

    ui void DrawHeader()
    {
        Color main = 0xB8C0C2;
        Color dim = 0x3C4448;
        Color steel = 0x778185;
        Color warn = 0xB9A875;

        Text("YARBIS", 25, 17, main, 0.43);
        Text("HELMET // INTERNAL", 25, 29, dim, 0.24);
        Text(hudMapName, 25, 40, steel, 0.25);

        TextC("NEURAL VISOR", 320, 17, dim, 0.25);
        TextC("SYSTEM LINK // 100%", 320, 28, main, 0.25);

        // Compact command bus embedded in the brow.
        // Explicit calls keep this block conservative for GZDoom 4.14.2
        // and make each control independently readable.
        Text("W", 240, 41, dim, 0.22);
        Text("A", 255, 41, dim, 0.22);
        Text("S", 270, 41, dim, 0.22);
        Text("D", 285, 41, dim, 0.22);
        Text("SP", 303, 41, dim, 0.22);
        Text("CT", 325, 41, dim, 0.22);
        Text("M1", 346, 41, dim, 0.22);
        Text("M2", 369, 41, dim, 0.22);
        Text("M3", 392, 41, dim, 0.22);
        Text("R", 414, 41, warn, 0.22);

        int bt = 0;
        if (consoleplayer >= 0 && consoleplayer < MAXPLAYERS)
        {
            let p = players[consoleplayer].mo;
            if (p && p.player) bt = p.player.cmd.buttons;
        }

        Line(240, 48, 246, 48, (bt & BT_FORWARD) ? main : dim, 190, 1.0);
        Line(255, 48, 261, 48, (bt & BT_MOVELEFT) ? main : dim, 190, 1.0);
        Line(270, 48, 276, 48, (bt & BT_BACK) ? main : dim, 190, 1.0);
        Line(285, 48, 291, 48, (bt & BT_MOVERIGHT) ? main : dim, 190, 1.0);
        Line(303, 48, 311, 48, (bt & BT_JUMP) ? main : dim, 190, 1.0);
        Line(325, 48, 333, 48, (bt & BT_CROUCH) ? main : dim, 190, 1.0);
        Line(346, 48, 354, 48, (bt & BT_ATTACK) ? main : dim, 190, 1.0);
        Line(369, 48, 377, 48, (bt & BT_ALTATTACK) ? main : dim, 190, 1.0);
        Line(392, 48, 400, 48, tlhInputM3Down ? main : dim, 190, 1.0);
        Line(414, 48, 420, 48, (bt & BT_RELOAD) ? main : dim, 190, 1.0);

        TextR("DUAL / " .. (tlhHUDDualBindName == "" ? "G" : tlhHUDDualBindName),
            617, 17, tlhHUDDualActive ? Font.CR_GREEN : main, 0.25);
        TextR(tlhHUDDualActive ? "LEFT M1 / RIGHT M2" : "M1 FIRE / M2 ALT",
            617, 29, tlhHUDDualActive ? Font.CR_GREEN : dim, 0.22);
        TextR(tlhInputLast == "" ? "COMMAND BUS READY" : tlhInputLast,
            617, 40, steel, 0.21);

        Line(204, 54, 288, 54, dim, 105, 0.45);
        Line(352, 54, 436, 54, dim, 105, 0.45);
        Line(303, 54, 337, 54, warn, 120, 0.55);
    }

    // ========================================================================
    // CORNER TELEMETRY // MINIMAL BUT DENSE
    // ========================================================================

    ui void DrawTelemetry()
    {
        Color main = 0xAEB7BA;
        Color dim = 0x353D40;
        Color steel = 0x737D80;
        Color warn = 0xB9A875;

        // Left temple: suit telemetry.
        Panel(24, 70, 116, 60, dim, 90);
        Text("TEMPLE / A", 31, 74, steel, 0.23);
        Text("FOV", 31, 86, dim, 0.22);
        TextR(String.Format("%03d", int(hudFOV)), 132, 86, Font.CR_WHITE, 0.25);
        Text("ALT", 31, 97, dim, 0.22);
        TextR(String.Format("%04d", int(hudAltitude)), 132, 97, Font.CR_WHITE, 0.25);
        Text("VEL", 31, 108, dim, 0.22);
        TextR(String.Format("%03d", int(hudMoveSpeed)), 132, 108, Font.CR_WHITE, 0.25);
        TextR(hudOnGround ? "GND LOCK" : "FREE FALL", 132, 119,
            hudOnGround ? main : warn, 0.21);
        Line(31, 126, 132, 126, main, 105, 0.55);

        // Right temple: mission computer.
        Panel(500, 70, 116, 60, dim, 90);
        TextR("TEMPLE / B", 608, 74, steel, 0.23);
        TextR("MODE", 559, 86, dim, 0.22);
        TextR(hudModeName, 608, 86, main, 0.21);
        TextR("TIME", 559, 97, dim, 0.22);
        TextR(String.Format("%02d:%02d", (hudMapTime / 35) / 60,
            (hudMapTime / 35) % 60), 608, 97, Font.CR_WHITE, 0.25);
        TextR("LINK", 559, 108, dim, 0.22);
        TextR(tlhVisorActive ? "ACTIVE" : "STANDBY", 608, 108,
            tlhVisorActive ? Font.CR_GREEN : steel, 0.21);
        TextR(hudMapName, 608, 119, steel, 0.21);
        Line(508, 126, 608, 126, main, 105, 0.55);

        // Brow sensor ladder. It follows the shape of an internal HUD optical
        // rail and does not claim to be a compass heading.
        Line(244, 64, 396, 64, dim, 90, 0.5);
        for (int i = 0; i < 19; i++)
        {
            double x = 246 + i * 8.0;
            bool major = ((i % 4) == 0);
            bool center = (i == 9);
            Line(x, 64, x, 64 + (center ? 8 : major ? 5 : 3),
                center ? main : dim,
                center ? 190 : 80,
                center ? 0.85 : 0.45);
        }
        TextC("OPTICAL BUS", 320, 75, dim, 0.20);
    }

    // ========================================================================
    // CENTER OPTICAL NODE // DETAILED, STILL SMALL
    // ========================================================================

    ui void DrawOpticalNode()
    {
        Color main = 0xC1C7C8;
        Color dim = 0x294D48;
        Color warn = 0xB9A875;
        double t = double(tlhVisorTime);
        double pulse = 0.5 + 0.5 * sin(t * 0.12 * TLH_RAD_TO_DEG);

        // The actual eye-point remains almost completely empty.
        Arc(320, 180, 9.0, -42, -16, dim, 150, 0.55);
        Arc(320, 180, 9.0, 16, 42, dim, 150, 0.55);
        Arc(320, 180, 9.0, 138, 162, dim, 145, 0.55);
        Arc(320, 180, 9.0, 198, 222, dim, 145, 0.55);

        double r = 17.0 + pulse * 1.2;
        Arc(320, 180, r, 218, 248, dim, 90, 0.45);
        Arc(320, 180, r, 292, 322, dim, 90, 0.45);

        Line(312, 180, 317, 180, main, 205, 0.65);
        Line(323, 180, 328, 180, main, 205, 0.65);
        Line(320, 173, 320, 177, main, 205, 0.65);
        Line(320, 183, 320, 187, main, 205, 0.65);

        int scan = int(t * 0.55) % 24;
        for (int i = 0; i < 4; i++)
        {
            double a = -54 + i * 36 + scan * 0.25;
            double x0 = 320 + cos(a) * 23;
            double y0 = 180 + sin(a) * 23;
            double x1 = 320 + cos(a) * 26;
            double y1 = 180 + sin(a) * 26;
            Line(x0, y0, x1, y1, i == 2 ? warn : dim,
                i == 2 ? 170 : 70, 0.45);
        }

        TextC(tlhVisorActive ? "TACTICAL ANALYSIS" : "VISOR READY",
            320, 202,
            tlhVisorActive ? main : dim, 0.21);
    }

    // ========================================================================
    // LOWER LEFT // VITAL SYSTEMS
    // ========================================================================

    ui void DrawVitals()
    {
        Color main = 0xB8C0C2;
        Color dim = 0x353D40;
        Color warn = 0xD0B25B;
        Color hp = hudPlayerHealth < 40 ? 0xC65B55 : main;

        Panel(24, 271, 137, 61, dim, 95);
        Text("LEFT CHEEK // VITALS", 31, 275, main, 0.25);
        Text("HP", 31, 288, dim, 0.22);
        TextR(String.Format("%03d", max(0, hudPlayerHealth)), 70, 288,
            hudPlayerHealth < 40 ? Font.CR_RED : Font.CR_WHITE, 0.30);
        SegBar(74, 297, 78, hudPlayerHealth, TLH_MAX_HEALTH, 12, hp);

        Text("ARM", 31, 307, dim, 0.22);
        TextR(String.Format("%03d", max(0, hudArmor)), 70, 307,
            hudArmor < 50 ? Font.CR_YELLOW : Font.CR_WHITE, 0.28);
        SegBar(74, 316, 78, hudArmor, max(1, hudArmorMax), 12,
            hudArmor < 50 ? warn : 0x5F98A8);

        Text("KIN", 31, 325, dim, 0.21);
        TextR(hudOnGround ? "GND" : "AIR", 78, 325,
            hudOnGround ? main : warn, 0.22);
        TextR(String.Format("VZ %+04d", int(hudVerticalSpeed)), 155, 325,
            dim, 0.21);
    }

    // ========================================================================
    // PROCEDURAL WEAPON DISPLAY // USES THE ACTUAL ACTIVE PSPROPERTY
    // ========================================================================

    ui void GetHUDWeaponDesign(Weapon weapon, out Color primary, out Color secondary,
        out double profileX, out double profileY, out double accentStrength)
    {
        primary = 0xB8C0C2;
        secondary = 0x596164;
        profileX = 1.0;
        profileY = 1.0;
        accentStrength = 1.0;

        if (!weapon) return;

        String cls = weapon.GetClassName();

        if (cls == "OfficerVulkanPistol")
        {
            // Red/orange parts become steel-gray; original gray becomes darker.
            primary = 0x6E7775;
            secondary = 0x303735;
            profileX = 0.96;
            profileY = 1.06;
        }
        else if (cls == "SemiAutoShotgun")
        {
            // Muzzle/accent: controlled dark red, never neon.
            primary = 0x7B302D;
            secondary = 0x9B4240;
            profileX = 1.00;
            profileY = 1.16;
            accentStrength = 0.78;
        }
        else if (cls == "AMR99RailRifle")
        {
            // Lightened gray body + electric-blue BFG green-range accent.
            primary = 0xA4B0AD;
            secondary = 0x56B9D2;
            profileX = 0.96;
            profileY = 1.14;
            accentStrength = 1.10;
        }
        else if (cls == "HellfireProjector")
        {
            // Red nozzle + light-gray lower body.
            primary = 0xC53A35;
            secondary = 0xA5AFAD;
            profileX = 0.82;
            profileY = 0.86;
            accentStrength = 1.06;
        }
        else if (cls == "AirstrikeDesignator")
        {
            // Flare-red design, slightly larger.
            primary = 0xC93E39;
            secondary = 0x7B302D;
            profileX = 1.08;
            profileY = 1.12;
            accentStrength = 1.06;
        }
        else if (cls == "RecoilPistol")
        {
            primary = 0x8B9693;
            secondary = 0x35413F;
        }
        else if (cls == "HeavyChaingun")
        {
            primary = 0xA0AAA7;
            secondary = 0x303A37;
            profileX = 1.06;
            profileY = 1.12;
            accentStrength = 1.14;
        }
        else if (cls == "TLHCompactSMG")
        {
            primary = 0x7D8986;
            secondary = 0x35413F;
            profileX = 0.96;
            profileY = 1.02;
            accentStrength = 0.92;
        }
        else if (cls == "RecoilRocketLauncher")
        {
            primary = 0x909B97;
            secondary = 0x394440;
            profileX = 1.04;
            profileY = 1.08;
            accentStrength = 1.05;
        }
        else if (cls == "RecoilShotgun" || cls == "FastRecoilSSG")
        {
            primary = 0x909C99;
            secondary = 0x3D4A47;
        }
        else if (cls == "TacticalM4A1")
        {
            primary = 0x7D8986;
            secondary = 0x39423F;
        }
        else if (cls == "M60MachineGun")
        {
            primary = 0x68716F;
            secondary = 0x2E3533;
        }
        else if (cls == "RecoilRocketLauncher" || cls == "RecoilPlasmaRifle" ||
                 cls == "RecoilBFG9000")
        {
            primary = 0x7F8D89;
            secondary = 0x33413D;
        }
    }

    ui void DrawProceduralWeaponHUD()
    {
        if (consoleplayer < 0 || consoleplayer >= MAXPLAYERS) return;

        let p = players[consoleplayer].mo;
        if (!p || !p.player) return;

        Weapon weapon = p.player.ReadyWeapon;
        if (!weapon) return;

        String cls = weapon.GetClassName();

        // TEMPORARY SAFETY BYPASS: do not draw the HeavyChaingun's CHGG sprite
        // through the custom helmet HUD. This isolates the reported crash to
        // the HUD preview path while leaving the actual first-person weapon,
        // firing states, ammo, and world pickup unchanged.
        if (cls == "HeavyChaingun")
            return;

        Color primary = 0xB8C0C2;
        Color secondary = 0x596164;
        double profileX = 1.0;
        double profileY = 1.0;
        double accentStrength = 1.0;

        GetHUDWeaponDesign(weapon, primary, secondary, profileX, profileY, accentStrength);

        // --------------------------------------------------------------------
        // SAFE CURRENT-STATE PREVIEW
        // --------------------------------------------------------------------
        // The actual PSprite frame was sampled in WorldTick() and cached for
        // this UI pass. No play-scoped Weapon state function is called here.
        TextureID tex;
        bool flip = false;
        Vector2 stateScale = (1.0, 1.0);

        // HeavyChaingun uses the original DOOM II CHGG sprite family for the visor preview.
        // Keep a static A-frame fallback while the transient PSprite cache is empty.
        if (hudWeaponTextureValid && hudWeaponTextureClass == cls)
        {
            tex = hudWeaponTexture;
            flip = hudWeaponFlip;
            stateScale = hudWeaponStateScale;
        }
        else if (cls == "HeavyChaingun")
        {
            tex = TexMan.CheckForTexture("CHGGA0", TexMan.Type_Sprite);
        }
        else
        {
            return;
        }

        if (!tex.IsValid())
            return;

        Vector2 texSize = TexMan.GetScaledSize(tex);
        double tw = max(1.0, texSize.X);
        double th = max(1.0, texSize.Y);

        double liveScaleX = 1.0;
        double liveScaleY = 1.0;
        double liveRoll = 0.0;
        double liveBobX = 0.0;
        double liveBobY = 0.0;

        let tp = TacticalPlayer(p);
        if (tp)
        {
            liveScaleX = clamp(tp.tlhAnimAppliedWeaponScaleX, 0.82, 1.24);
            liveScaleY = clamp(tp.tlhAnimAppliedWeaponScaleY, 0.82, 1.28);
            liveRoll = clamp(tp.tlhAnimWeaponKickSide * 0.35, -4.0, 4.0);
            liveBobX = clamp(tp.tlhAnimSwayX * 0.55 + tp.tlhAnimInertiaX * 0.32, -8.0, 8.0);
            liveBobY = clamp(tp.tlhAnimSwayY * 0.40 + tp.tlhAnimInertiaY * 0.25, -6.0, 6.0);
        }

        double stateScaleX = clamp(abs(stateScale.X), 0.50, 2.00);
        double stateScaleY = clamp(abs(stateScale.Y), 0.50, 2.00);

        double fit = min(38.0 / tw, 23.0 / th);
        double dw = clamp(tw * fit * profileX * liveScaleX * stateScaleX, 18.0, 48.0);
        double dh = clamp(th * fit * profileY * liveScaleY * stateScaleY, 12.0, 30.0);

        double cx = 485.0 + liveBobX;
        double cy = 294.0 + liveBobY;

        // --------------------------------------------------------------------
        // TRUE PALETTE TRANSLATION, NOT TINT
        // --------------------------------------------------------------------
        // DTA_TranslationIndex alone is not enough for the HUD path when the
        // source is rendered through the truecolor/Vulkan drawer. DTA_Indexed
        // explicitly tells GZDoom to treat the source as an indexed image and
        // combine it with the supplied translation table. This is the same
        // translation system used by GZDoom's indexed HUD sprite rendering,
        // without putting a translucent color filter over the weapon.
        //
        // The translation comes from the weapon class, so Ready/Fire/Reload/
        // Select/Deselect frames all use the same authored weapon design.
        int hudTranslation = hudWeaponTranslation;
        if (hudTranslation == 0)
            hudTranslation = int(weapon.Translation);

        Screen.DrawTexture(
            tex, false,
            cx - dw * 0.5, cy - dh * 0.5,
            DTA_DestWidthF, dw,
            DTA_DestHeightF, dh,
            DTA_VirtualWidth, 640,
            DTA_VirtualHeight, 360,
            DTA_TranslationIndex, hudTranslation,
            DTA_Indexed, true,
            DTA_FlipX, flip,
            DTA_Rotate, liveRoll,
            DTA_RenderStyle, STYLE_Normal,
            DTA_Masked, true,
            DTA_KeepRatio, true);

        // Procedural hardware around the preview follows the same transform.
        double bracket = 23.0 + abs(liveBobX) * 0.25;
        Line(cx - bracket, cy - 14, cx - bracket + 5, cy - 14, primary, 190, 0.70);
        Line(cx - bracket, cy - 14, cx - bracket, cy - 9, primary, 160, 0.55);
        Line(cx + bracket, cy + 14, cx + bracket - 5, cy + 14, secondary, 175, 0.70);
        Line(cx + bracket, cy + 14, cx + bracket, cy + 9, secondary, 150, 0.55);

        double accentLen = clamp(8.0 * accentStrength, 5.0, 10.0);
        Line(cx - accentLen, cy + 13.5, cx + accentLen, cy + 13.5, secondary, 145, 0.65);

        if (tlhHUDDualActive)
        {
            double lcx = 511.0 + liveBobX * 0.75;
            Screen.DrawTexture(
                tex, false,
                lcx - dw * 0.5, cy - dh * 0.5,
                DTA_DestWidthF, dw,
                DTA_DestHeightF, dh,
                DTA_VirtualWidth, 640,
                DTA_VirtualHeight, 360,
                DTA_TranslationIndex, hudTranslation,
                DTA_Indexed, true,
                DTA_FlipX, !flip,
                DTA_Rotate, -liveRoll,
                DTA_RenderStyle, STYLE_Normal,
                DTA_Masked, true,
                DTA_KeepRatio, true);

            Line(lcx - 20, cy - 14, lcx - 14, cy - 14, primary, 170, 0.55);
            Text("L/R", 500, 309, secondary, 0.19);
        }
    }

    // ========================================================================
    // LOWER RIGHT // ARMAMENT + THREAT
    // ========================================================================

    ui void DrawCombat()
    {
        Color main = 0x61C6B1;
        Color dim = 0x24443F;
        Color warn = 0xD3B35B;

        Panel(454, 271, 162, 72, dim, 95);
        TextR("RIGHT CHEEK // ARMAMENT", 609, 275, main, 0.25);
        TextR(hudWeaponName, 609, 287, Font.CR_WHITE, 0.23);

        // The actual current weapon frame is rendered inside the helmet
        // module, so its palette design visibly changes with the weapon.
        DrawProceduralWeaponHUD();

        if (tlhVisorWeaponClass == "ServiceRevolver")
        {
            Text("CYLINDER", 518, 306, dim, 0.21);
            TextR(String.Format("%02d/06", hudRevolverAmmo), 609, 306,
                hudRevolverAmmo <= 1 ? warn : Font.CR_WHITE, 0.25);
            Text("RESERVE", 518, 317, dim, 0.21);
            TextR(String.Format("%03d", hudRevolverReserve), 609, 317, Font.CR_WHITE, 0.23);
        }
        else
        {
            Text("BUL", 518, 306, dim, 0.21);
            TextR(String.Format("%03d", hudClip), 555, 306, Font.CR_WHITE, 0.24);
            Text("SHE", 564, 306, dim, 0.21);
            TextR(String.Format("%03d", hudShell), 609, 306, Font.CR_WHITE, 0.24);

            Text("RCK", 518, 317, dim, 0.21);
            TextR(String.Format("%03d", hudRocket), 555, 317, Font.CR_WHITE, 0.24);
            Text("CEL", 564, 317, dim, 0.21);
            TextR(String.Format("%03d", hudCell), 609, 317, Font.CR_WHITE, 0.24);
        }

        Text("HOST", 518, 328, dim, 0.21);
        TextR(String.Format("%03d", hudLiveEnemies), 555, 328,
            hudLiveEnemies > 0 ? Font.CR_RED : main, 0.27);
        Text("DOWN", 570, 328, dim, 0.21);
        TextR(String.Format("%03d", hudKills), 609, 328, warn, 0.23);

        Text("LINK", 518, 338, dim, 0.21);
        TextR(tlhHUDDualActive ? "AKIMBO" : "NORMAL", 609, 338,
            tlhHUDDualActive ? Font.CR_GREEN : dim, 0.21);
    }

    // ========================================================================
    // HELMET GLASS MICRO-DETAIL // VERY LIGHT, VERY PERIPHERAL
    // ========================================================================

    ui void DrawHelmetGlassDetail()
    {
        Color dim = 0x142A28;
        Color shell = 0x2B4D48;
        Color main = 0x4D9D90;

        // Faint inner visor seams. These occupy the edge of the eye viewport,
        // never the central play space.
        Line(62, 66, 122, 54, dim, 70, 0.45);
        Line(578, 54, 518, 66, dim, 70, 0.45);
        Line(53, 70, 53, 142, dim, 70, 0.45);
        Line(587, 70, 587, 142, dim, 70, 0.45);

        // Tiny reflection cuts, animated slowly as if the visor glass itself
        // were moving relative to the player's head.
        int p = tlhVisorTime % 90;
        double x = 205 + double(p) * 0.55;
        Line(x, 61, x + 20, 61, shell, 45, 0.4);
        Line(435 - double(p) * 0.55, 61, 415 - double(p) * 0.55, 61,
            shell, 45, 0.4);

        // Chin support indicators flank the face camera.
        Line(258, 328, 270, 328, main, 95, 0.45);
        Line(370, 328, 382, 328, main, 95, 0.45);
        Line(250, 331, 258, 331, dim, 65, 0.4);
        Line(382, 331, 390, 331, dim, 65, 0.4);

        // Interior helmet hardware: cheek brackets and small ventilation teeth.
        Line(36, 274, 92, 318, shell, 95, 0.55);
        Line(604, 274, 548, 318, shell, 95, 0.55);
        Line(48, 283, 98, 322, dim, 70, 0.4);
        Line(592, 283, 542, 322, dim, 70, 0.4);

        for (int i = 0; i < 7; i++)
        {
            double xL = 76 + i * 5.0;
            double xR = 564 - i * 5.0;
            double h = (i & 1) == 0 ? 3.0 : 5.0;
            Line(xL, 323, xL + 2.0, 323 - h, shell, 70, 0.4);
            Line(xR, 323, xR - 2.0, 323 - h, shell, 70, 0.4);
        }
    }

    // ========================================================================
    // PERIPHERAL ANALYZER // 3D PROJECTION, NEVER CENTERED AS A BLOCK
    // ========================================================================

    ui bool ProjectWorld(Vector3 worldPos, RenderEvent e,
        double fov, out double sx, out double sy, out double depth)
    {
        sx = 0; sy = 0; depth = 0;
        Vector3 rel = worldPos - e.ViewPos;

        double yaw = e.ViewAngle;
        double pitch = e.ViewPitch;
        double roll = e.ViewRoll;
        double cp = cos(pitch);
        double sp = sin(pitch);
        double cy = cos(yaw);
        double syaw = sin(yaw);

        Vector3 forward = (cp * cy, cp * syaw, -sp);
        Vector3 right = (syaw, -cy, 0);
        Vector3 up = right cross forward;
        double cr = cos(roll);
        double sr = sin(roll);
        Vector3 rr = right * cr + up * sr;
        Vector3 ru = up * cr - right * sr;

        double cx = rel dot rr;
        double cyh = rel dot ru;
        depth = rel dot forward;
        if (depth <= 0.05) return false;

        double hf = tan(clamp(fov, 20.0, 160.0) * 0.5);
        double aspect = max(0.1, Screen.GetAspectRatio());
        double vf = hf / aspect;
        if (abs(hf) < 0.0001 || abs(vf) < 0.0001) return false;

        double nx = cx / (depth * hf);
        double ny = cyh / (depth * vf);
        sx = 320 + nx * 320;
        sy = 180 - ny * 180;
        return sx >= -24 && sx <= 664 && sy >= -24 && sy <= 384;
    }

    ui void AnalyzerMarker(Actor mo, RenderEvent e, Color c, bool enemy)
    {
        if (!mo || mo.Health <= 0) return;

        let p = players[consoleplayer].mo;
        if (!p || !p.player) return;

        double fov = clamp(double(p.player.FOV), 20.0, 160.0);
        Vector3 pos = mo.Pos + (0, 0, enemy ? mo.Height * 0.55 : 8.0);
        double x, y, depth;
        if (!ProjectWorld(pos, e, fov, x, y, depth)) return;

        double size = clamp(15.0 * sqrt(96.0 / max(24.0, depth)), 4.0, 14.0);
        Line(x - size, y - size, x - size * 0.30, y - size, c, 180, 0.75);
        Line(x - size, y - size, x - size, y - size * 0.30, c, 180, 0.75);
        Line(x + size, y + size, x + size * 0.30, y + size, c, 180, 0.75);
        Line(x + size, y + size, x + size, y + size * 0.30, c, 180, 0.75);

        // Tiny center dot makes targets easy to acquire without a big box.
        Line(x - 1.5, y, x + 1.5, y, c, 145, 0.55);
        Line(x, y - 1.5, x, y + 1.5, c, 145, 0.55);

        if (enemy)
            TextC(String.Format("%03d", int(depth)), x, y + size + 2,
                Font.CR_RED, 0.23);
    }

    ui void DrawPeripheralAnalyzer(RenderEvent e)
    {
        if (!tlhVisorActive) return;

        Color red = 0xD45B55;
        Color yellow = 0xB9A875;
        Color cyan = 0x9AAEB3;

        int enemyLimit = min(10, tlhVisorEnemies.Size());
        for (int i = 0; i < enemyLimit; i++)
            AnalyzerMarker(tlhVisorEnemies[i], e, red, true);

        int weaponLimit = min(6, tlhVisorWeapons.Size());
        for (int i = 0; i < weaponLimit; i++)
            AnalyzerMarker(tlhVisorWeapons[i], e, yellow, false);

        int projLimit = min(6, tlhVisorProjectiles.Size());
        for (int i = 0; i < projLimit; i++)
        {
            Actor mo = tlhVisorProjectiles[i];
            if (!mo) continue;
            double x, y, depth;
            if (ProjectWorld(mo.Pos, e, hudFOV, x, y, depth))
            {
                Line(x - 3, y, x + 3, y, cyan, 185, 0.8);
                Line(x, y - 3, x, y + 3, cyan, 185, 0.8);
            }
        }

        // Only a tiny corner readout. The actual enemy count lives in the
        // lower-right combat module, keeping duplicate text out of the center.
        Text("THREAT SCAN", 23, 132, red, 0.24);
        TextR(String.Format("%02d HOSTILES", tlhVisorEnemies.Size()), 617, 132, red, 0.24);
    }

    // ========================================================================
    // SSG CHAIN // SMALL PROCEDURAL DETAIL
    // ========================================================================

    ui void DrawSSGChainCompact()
    {
        if (!tlhSSGVisible) return;
        Color dark = 0x31413F;
        Color metal = 0x8E9D9A;
        Color hi = 0xC8D0CC;

        double baseX = 534 + tlhSSGOffsetX * 0.16;
        double baseY = 238 + tlhSSGOffsetY * 0.12;
        int links = 6;
        for (int i = 0; i < links; i++)
        {
            double x = baseX + i * 3.9;
            double y = baseY + sin((tlhSSGPhase + i * 7) * 0.12 * TLH_RAD_TO_DEG) * 0.9;
            Line(x, y, x + 3.0, y + 1.0, dark, 190, 1.25);
            Line(x + 0.5, y - 0.15, x + 2.6, y + 0.45, metal, 170, 0.65);
            if ((i & 1) == 0)
                Line(x + 0.9, y - 0.15, x + 1.7, y - 0.6, hi, 125, 0.4);
        }
    }

    // ========================================================================
    // ROOT YARBIS VISOR
    // ========================================================================

    override void RenderOverlay(RenderEvent e)
    {
        // Render callbacks may be invoked during transitions; bail out if the
        // event or local player context is not valid.
        if (!e) return;
        if (consoleplayer < 0 || consoleplayer >= MAXPLAYERS) return;

        let p = players[consoleplayer].mo;
        if (!p || !p.player) return;

        DrawPerimeter();
        DrawHeader();
        DrawTelemetry();
        DrawOpticalNode();
        DrawVitals();
        DrawCombat();
        DrawHelmetGlassDetail();
        DrawFaceNode();
        DrawPeripheralAnalyzer(e);
        DrawSSGChainCompact();
        DrawAimTargetLabel(p, e);
    }

}

// MAPINFO in this build also registers TacticalHUDHandler. Keep the legacy
// entry inert so it cannot run the same global callbacks a second time.
class TLHYarbisHelmetVisor : EventHandler
{
}

// Retained as an inert compatibility class. Target identification is handled
// by TacticalHUDHandler using AimLineAttack.
class DeveloperAdvancedHUD : EventHandler
{
}

class RemoveStartingPistol : EventHandler
{
    bool removalPending[MAXPLAYERS];

    override void PlayerEntered(PlayerEvent e)
    {
        QueueRemoval(e.PlayerNumber);
    }

    override void PlayerRespawned(PlayerEvent e)
    {
        QueueRemoval(e.PlayerNumber);
    }

    void QueueRemoval(int playerNum)
    {
        if (playerNum >= 0 && playerNum < MAXPLAYERS)
            removalPending[playerNum] = true;
    }

    override void WorldTick()
    {
        for (int playerNum = 0; playerNum < MAXPLAYERS; playerNum++)
        {
            if (!removalPending[playerNum])
                continue;

            Actor pawn = players[playerNum].mo;
            if (!pawn || !pawn.player)
                continue;

            Weapon pistol = Weapon(pawn.FindInventory("RecoilPistol"));
            if (!pistol)
                pistol = Weapon(pawn.FindInventory("Pistol"));

            if (!pistol)
            {
                removalPending[playerNum] = false;
                continue;
            }

            Weapon fist = Weapon(pawn.FindInventory("DashFist"));
            if (!fist)
                fist = Weapon(pawn.FindInventory("Fist"));
            if (!fist)
                continue;

            if (players[playerNum].ReadyWeapon == pistol || !players[playerNum].ReadyWeapon)
            {
                players[playerNum].PendingWeapon = fist;
                continue;
            }

            if (players[playerNum].PendingWeapon == pistol)
                players[playerNum].PendingWeapon = WP_NOCHANGE;

            PSprite weaponPSprite = players[playerNum].FindPSprite(PSP_WEAPON);
            if (weaponPSprite && weaponPSprite.Caller == pistol)
                continue;

            pawn.TakeInventory("RecoilPistol", 1);
            pawn.TakeInventory("Pistol", 1);
            removalPending[playerNum] = false;
        }
    }
}

// ============================================================================
// 7. BACKPACK Y DROPS
// ============================================================================
// LoadoutBackpack is a real CustomInventory actor and can be spawned by name
// from maps, scripts or the existing MAPINFO DoomEdNum mapping. MilitaryBackpack
// remains as a compatibility subclass so older maps do not break.

class MilitaryBackpack : CustomInventory
{
    Default
    {
        +COUNTITEM
        Inventory.PickupMessage "I picked up a Military Backpack!";
        Inventory.PickupSound "misc/w_pkup";
    }

    States
    {
    Spawn:
        BPAK A -1;
        Stop;

    Pickup:
        TNT1 A 0
        {
            A_GiveInventory("Backpack", 1);

            // Military cache: three equally likely combat packages.
            int cache = random(1, 3);
            if (cache == 1)
            {
                A_GiveInventory("SemiAutoShotgun", 1);
                A_GiveInventory("Shell", 24);
                A_Print("\c[DarkGreen]MILITARY CACHE: \c[White]SEMI-AUTO SHOTGUN");
            }
            else if (cache == 2)
            {
                A_GiveInventory("M60MachineGun", 1);
                A_GiveInventory("Clip", 180);
                A_Print("\c[DarkGreen]MILITARY CACHE: \c[White]M60 MACHINE GUN");
            }
            else
            {
                A_GiveInventory("OfficerVulkanPistol", 1);
                A_GiveInventory("Clip", 80);
                A_GiveInventory("Shell", 6);
                A_Print("\c[DarkGreen]MILITARY CACHE: \c[White]OFFICER VULKAN");
            }

            A_GiveInventory("TacticalMedikit", 1);
            A_GiveInventory("KevlarArmor", 1);
        }
        Stop;
    }
}

class LoadoutBackpack : CustomInventory
{
    Default
    {
        +COUNTITEM
        Inventory.PickupMessage "I picked up a Loadout Backpack!";
        Inventory.PickupSound "misc/w_pkup";
        // Near-black visual variant of the normal Doom backpack.
    }

    States
    {
    Spawn:
        BPAK A -1;
        Stop;

    Pickup:
        TNT1 A 0
        {
            // Standard backpack capacity still comes with the kit.
            A_GiveInventory("Backpack", 1);

            // Nerfed survivability package: one small armor bonus and one
            // modest medical boost instead of a huge defensive refill.
            A_GiveInventory("KevlarArmor", 1);
            A_GiveInventory("TacticalStimpack", 1);

            // Ten complete kits remain uniformly weighted: exactly 10% each.
            // The balancing rule is intentional: one strong slot at most,
            // no BFG, and special weapons receive deliberately limited ammo.
            int loadout = random(0, 9);
            String primary;
            String secondary;
            String light;
            String special;
            String loadoutName;

            int clipAmmo = 0;
            int shellAmmo = 0;
            int rocketAmmo = 0;
            int cellAmmo = 0;

            if (loadout == 0)
            {
                loadoutName = "URBAN ASSAULT";
                primary = "TacticalM4A1";
                secondary = "RecoilPistol";
                light = "DashFist";
                special = "SemiAutoShotgun";
                clipAmmo = 100;
                shellAmmo = 24;
            }
            else if (loadout == 1)
            {
                loadoutName = "BREACHER";
                primary = "RecoilShotgun";
                secondary = "OfficerVulkanPistol";
                light = "HookChainsaw";
                special = "TacticalM4A1";
                clipAmmo = 70;
                shellAmmo = 40;
            }
            else if (loadout == 2)
            {
                loadoutName = "SUPPORT";
                primary = "M60MachineGun";
                secondary = "RecoilPistol";
                light = "DashFist";
                special = "RecoilShotgun";
                clipAmmo = 150;
                shellAmmo = 16;
            }
            else if (loadout == 3)
            {
                loadoutName = "MARKSMAN";
                primary = "AMR99RailRifle";
                secondary = "RecoilPistol";
                light = "HookChainsaw";
                special = "TacticalM4A1";
                clipAmmo = 70;
                cellAmmo = 30;
            }
            else if (loadout == 4)
            {
                loadoutName = "ENERGY";
                primary = "RecoilPlasmaRifle";
                secondary = "OfficerVulkanPistol";
                light = "DashFist";
                special = "RecoilShotgun";
                clipAmmo = 60;
                shellAmmo = 18;
                cellAmmo = 160;
            }
            else if (loadout == 5)
            {
                loadoutName = "DEMOLITION";
                primary = "TacticalM4A1";
                secondary = "RecoilPistol";
                light = "HookChainsaw";
                special = "RecoilRocketLauncher";
                clipAmmo = 100;
                rocketAmmo = 6;
            }
            else if (loadout == 6)
            {
                loadoutName = "ASSAULT";
                primary = "FastRecoilSSG";
                secondary = "RecoilPistol";
                light = "DashFist";
                special = "RecoilPlasmaRifle";
                shellAmmo = 42;
                cellAmmo = 100;
            }
            else if (loadout == 7)
            {
                loadoutName = "FIRE SUPPORT";
                primary = "M60MachineGun";
                secondary = "RecoilPistol";
                light = "HookChainsaw";
                special = "HellfireProjector";
                clipAmmo = 140;
                rocketAmmo = 5;
            }
            else if (loadout == 8)
            {
                loadoutName = "RECON";
                primary = "TacticalM4A1";
                secondary = "RecoilPistol";
                light = "HookChainsaw";
                special = "AMR99RailRifle";
                clipAmmo = 90;
                cellAmmo = 20;
            }
            else
            {
                loadoutName = "ADVANCED";
                primary = "AMR99RailRifle";
                secondary = "RecoilPistol";
                light = "DashFist";
                special = "RecoilRocketLauncher";
                clipAmmo = 50;
                rocketAmmo = 4;
                cellAmmo = 20;
            }

            A_GiveInventory(primary, 1);
            A_GiveInventory(secondary, 1);
            A_GiveInventory(light, 1);
            A_GiveInventory(special, 1);

            if (clipAmmo > 0) A_GiveInventory("Clip", clipAmmo);
            if (shellAmmo > 0) A_GiveInventory("Shell", shellAmmo);
            if (rocketAmmo > 0) A_GiveInventory("RocketAmmo", rocketAmmo);
            if (cellAmmo > 0) A_GiveInventory("Cell", cellAmmo);

            A_Print(String.Format("\c[DarkGreen]LOADOUT ACQUIRED: \c[White]%s\c[DarkGreen] | P %s | S %s | L %s | X %s",
                loadoutName, primary, secondary, light, special));
        }
        Stop;
    }
}


class TacticalZombieDrop : Actor
{
    States
    {
    Spawn:
        TNT1 A 0 NoDelay
        {
            bool isFirstMap = (level.levelnum == 1 || level.mapname ~== "MAP01" || level.mapname ~== "E1M1");
            Actor drop;

            if (!isFirstMap)
            {
                // Keep the same 5% total firearm-drop chance after MAP01:
                // 3% Service Revolver, 2% Officer Vulkan Pistol.
                int roll = random(1, 100);
                if (roll <= 3)
                    drop = Spawn("ServiceRevolver", Pos);
                else if (roll <= 5)
                    drop = Spawn("OfficerVulkanPistol", Pos);
                else
                    drop = Spawn("Clip", Pos);
            }
            else
            {
                drop = Spawn("Clip", Pos);
            }

            if (drop)
            {
                drop.bDROPPED = true;
                drop.Vel = (FRandom(-2.5, 2.5), FRandom(-2.5, 2.5), FRandom(2.0, 4.5));
            }
        }
        Stop;
    }
}

class TacticalZombieMan : ZombieMan replaces ZombieMan
{
    Default
    {
        DropItem "TacticalZombieDrop";
    }
}

class TacticalShotgunDrop : Actor
{
    States
    {
    Spawn:
        TNT1 A 0 NoDelay
        {
            bool isFirstMap = (level.levelnum == 1 || level.mapname ~== "MAP01" || level.mapname ~== "E1M1");
            Actor drop;

            if (!isFirstMap && random(1, 100) <= 5)
                drop = Spawn("SemiAutoShotgun", Pos);
            else
                drop = Spawn("RecoilShotgun", Pos);

            if (drop)
            {
                drop.bDROPPED = true;
                drop.Vel = (FRandom(-2.5, 2.5), FRandom(-2.5, 2.5), FRandom(2.0, 4.5));
            }
        }
        Stop;
    }
}

class TacticalShotgunGuy : ShotgunGuy replaces ShotgunGuy
{
    Default
    {
        DropItem "TacticalShotgunDrop";
    }
}

class TacticalChaingunDrop : Actor
{
    States
    {
    Spawn:
        TNT1 A 0 NoDelay
        {
            bool isFirstMap = (level.levelnum == 1 || level.mapname ~== "MAP01" || level.mapname ~== "E1M1");
            Actor drop;

            if (!isFirstMap)
            {
                int r = random(1, 100);
                if (r <= 5)
                    drop = Spawn("M60MachineGun", Pos);
                else if (r <= 15)
                    drop = Spawn("HeavyChaingun", Pos);
                else if (r <= 20)
                    drop = Spawn("OfficerVulkanPistol", Pos);
                else
                    drop = Spawn("TacticalM4A1", Pos);
            }
            else
            {
                drop = Spawn("TacticalM4A1", Pos);
            }

            if (drop)
            {
                drop.bDROPPED = true;
                drop.Vel = (FRandom(-2.5, 2.5), FRandom(-2.5, 2.5), FRandom(2.0, 4.5));
            }
        }
        Stop;
    }
}

class TacticalChaingunGuy : ChaingunGuy replaces ChaingunGuy
{
    Default
    {
        DropItem "TacticalChaingunDrop";
    }
}

// ============================================================================
// 9.5. ENEMIGOS ADICIONALES
//
// Variantes nuevas usando exclusivamente sprites/IA vanilla. Esto evita
// depender de nuevos sprites y permite que los modos Horde/Arena mezclen
// enemigos normales con variantes más pesadas.
// ============================================================================

class TLH_AssaultImp : DoomImp
{
    Default
    {
        Health 140;
        Speed 11;
        FastSpeed 15;
        PainChance 48;
    }
}

class TLH_HeavyShotgunGuy : ShotgunGuy
{
    Default
    {
        Health 120;
        Speed 11;
        FastSpeed 15;
        PainChance 18;
    }
}

class TLH_BerserkerDemon : Demon
{
    Default
    {
        Health 360;
        Speed 13;
        FastSpeed 16;
        PainChance 24;
    }
}

class TLH_RavagerRevenant : Revenant
{
    Default
    {
        Health 550;
        Speed 12;
        FastSpeed 16;
        PainChance 8;
    }
}

class TLH_HeavyMancubus : Fatso
{
    Default
    {
        Health 900;
        Speed 7;
        FastSpeed 9;
        PainChance 6;
        Radius 24;
        Height 64;
    }
}

class TLH_CombatBaron : BaronOfHell
{
    Default
    {
        Health 1400;
        Speed 9;
        FastSpeed 11;
        PainChance 8;
    }
}

class TLH_AssaultArachnotron : Arachnotron
{
    Default
    {
        Health 900;
        Speed 10;
        FastSpeed 12;
        PainChance 12;
    }
}

class TLH_VanguardCacodemon : Cacodemon
{
    Default
    {
        Health 600;
        Speed 12;
        FastSpeed 14;
        PainChance 10;
    }
}

class TLH_ArmoredHellKnight : HellKnight
{
    Default
    {
        Health 900;
        Speed 10;
        FastSpeed 13;
        PainChance 8;
        DamageFactor "Normal", 0.75;
    }
}

class TLH_SiegeRevenant : Revenant
{
    Default
    {
        Health 700;
        Speed 10;
        FastSpeed 14;
        PainChance 5;
        DamageFactor "Normal", 0.80;
    }
}

class TLH_HeavyDemon : Demon
{
    Default
    {
        Health 500;
        Speed 11;
        FastSpeed 14;
        PainChance 18;
        Radius 18;
        Height 56;
    }
}

class TLH_BloodCacodemon : Cacodemon
{
    Default
    {
        Health 800;
        Speed 10;
        FastSpeed 13;
        PainChance 8;
    }
}

class TLH_HellfireBaron : BaronOfHell
{
    Default
    {
        Health 1800;
        Speed 7;
        FastSpeed 10;
        PainChance 5;
        DamageFactor "Normal", 0.65;
    }
}

// Additional enemy variants. All inherit from actor classes that are valid
// in GZDoom 4.14.2. In particular, Mancubus variants inherit from Fatso,
// which is the engine class actually used by Doom's Mancubus.

class TLH_TacticalMancubus : Fatso
{
    Default
    {
        Health 1100;
        Speed 9;
        FastSpeed 11;
        PainChance 5;
        Radius 24;
        Height 64;
        DamageFactor "Normal", 0.80;
    }
}

class TLH_SiegeArachnotron : Arachnotron
{
    Default
    {
        Health 1200;
        Speed 8;
        FastSpeed 10;
        PainChance 7;
        DamageFactor "Normal", 0.80;
    }
}

class TLH_DevastatorRevenant : Revenant
{
    Default
    {
        Health 950;
        Speed 11;
        FastSpeed 15;
        PainChance 4;
        DamageFactor "Normal", 0.85;
    }
}

class TLH_VoidCacodemon : Cacodemon
{
    Default
    {
        Health 1100;
        Speed 9;
        FastSpeed 12;
        PainChance 6;
        DamageFactor "Normal", 0.80;
    }
}

class TLH_BrutalImp : DoomImp
{
    Default
    {
        Health 220;
        Speed 10;
        FastSpeed 14;
        PainChance 38;
        DamageFactor "Normal", 0.90;
    }
}

class TLH_ExecutionerBaron : BaronOfHell
{
    Default
    {
        Health 2200;
        Speed 6;
        FastSpeed 9;
        PainChance 4;
        DamageFactor "Normal", 0.60;
    }
}

// ============================================================================
// 9.6. CINCO ENEMIGOS DE ELITE ADICIONALES
// ============================================================================
// These reuse Doom's existing sprites/AI bases, but their combat numbers and
// two missile behaviors make them distinct enough to be actual TLH enemies.
// They are tuned to be dangerous without becoming boring bullet sponges.

class TLH_StalkerImp : DoomImp
{
    Default
    {
        Health 300;
        Speed 17;
        FastSpeed 21;
        PainChance 80;
        DamageFactor "Normal", 0.65;
        HitObituary "$OB_IMPHIT";
        Obituary "was stalked by a TLH Stalker Imp";
    }

    States
    {
    Missile:
        TROO EF 5 A_FaceTarget;
        TROO G 4
        {
            A_CustomMissile("TrackingMicroMissile", 36, -6, 4);
            A_CustomMissile("TrackingMicroMissile", 36, 6, -4);
        }
        Goto See;
    }
}

class TLH_BreacherShotgunner : ShotgunGuy
{
    Default
    {
        Health 300;
        Speed 14;
        FastSpeed 18;
        PainChance 40;
        DamageFactor "Normal", 0.60;
        +DONTTHRUST
        Obituary "was breached by a TLH Breacher";
    }
}

class TLH_RazorDemon : Demon
{
    Default
    {
        Health 700;
        Speed 17;
        FastSpeed 21;
        PainChance 45;
        DamageFactor "Normal", 0.68;
        Radius 18;
        Height 56;
        +DONTTHRUST
        Obituary "was shredded by a TLH Razor Demon";
    }
}

class TLH_HunterRevenant : Revenant
{
    Default
    {
        Health 1000;
        Speed 15;
        FastSpeed 19;
        PainChance 24;
        DamageFactor "Normal", 0.65;
        Obituary "was hunted by a TLH Hunter Revenant";
    }

    States
    {
    Missile:
        SKEL J 0 Bright A_FaceTarget;
        SKEL J 7 Bright A_FaceTarget;
        SKEL K 4
        {
            A_CustomMissile("TrackingMicroMissile", 36, -7, 5);
            A_CustomMissile("TrackingMicroMissile", 36, 7, -5);
        }
        SKEL K 6 A_FaceTarget;
        Goto See;
    }
}

class TLH_AssaultBaron : BaronOfHell
{
    Default
    {
        Health 2400;
        Speed 12;
        FastSpeed 15;
        PainChance 16;
        DamageFactor "Normal", 0.55;
        Obituary "was overrun by a TLH Assault Baron";
    }
}

// ==========================================
// 10. ENEMIGO ELITE - DOOMGUY
// ==========================================
//
// Usa exclusivamente los sprites PLAY del Doomguy.
// Diseñado para ser colocado desde UDB mediante DoomEdNum.
// No reemplaza al DoomPlayer ni modifica al jugador.
//
// Caracteristicas:
// - 1800 HP
// - Daño recibido reducido
// - Alta velocidad
// - Ataque melee devastador
// - Cohetes y plasma a distancia
// - Animaciones reutilizadas del Doomguy vanilla
// ==========================================

class TLH_DoomguyElite : Actor
{
    Default
    {
        Health 1800;
        Radius 16;
        Height 56;
        Mass 800;
        Speed 16;
        FastSpeed 22;
        PainChance 8;

        DamageFactor "Normal", 0.30;
        +NORADIUSDMG
        +BOSS
        +FLOORCLIP
        +DONTTHRUST

        Monster;

        SeeSound "grunt/sight";
        ActiveSound "grunt/active";
        PainSound "player/male/pain100";
        DeathSound "player/male/death";
    }

    States
    {
    Spawn:
        PLAY A 4 A_Look;
        Loop;

    See:
        PLAY ABCD 3 A_Chase;
        Loop;

    Missile:
        PLAY E 0 A_FaceTarget;
        PLAY E 0 A_Jump(96, "RocketAttack");
        Goto PlasmaAttack;

    PlasmaAttack:
        PLAY E 3 A_FaceTarget;
        PLAY E 2
        {
            A_CustomMissile("PlasmaBall", 32, -7, -5);
            A_CustomMissile("PlasmaBall", 32, 7, 5);
        }
        PLAY E 5;
        Goto See;

    RocketAttack:
        PLAY E 3 A_FaceTarget;
        PLAY E 3
            A_CustomMissile("Rocket", 36, 0, 0);
        PLAY E 4;
        Goto See;

    Melee:
        PLAY F 3 A_FaceTarget;
        PLAY F 3
            A_CustomMeleeAttack(100, "weapons/punch", "weapons/punch");
        PLAY F 4;
        Goto See;

    Pain:
        PLAY G 4 A_Pain;
        Goto See;

    Death:
        PLAY H 6;
        PLAY I 6 A_Scream;
        PLAY J 6 A_NoBlocking;
        PLAY KLM 6;
        PLAY N -1;
        Stop;

    XDeath:
        PLAY O 5 A_XScream;
        PLAY P 5;
        PLAY Q 5 A_NoBlocking;
        PLAY RSTUV 5;
        PLAY W -1;
        Stop;
    }
}


