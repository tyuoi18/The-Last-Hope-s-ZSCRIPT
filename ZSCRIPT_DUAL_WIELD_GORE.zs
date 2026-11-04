// ============================================================================
// TLH v52.25 - persistent Dual Wield auto-release on queued weapon switch; configurable gore controls
// PROCEDURAL PSprite MIRROR / PLAYER-OWNED DUAL WIELD / HELMET HUD
//
// R remains untouched. Dual Wield input is intercepted by TacticalHUDHandler.InputProcess
// using the user's actual +user3 binding, then routed through NetworkCommandProcess.
// Weapons do not use User3 states or WRF_ALLOWUSER3. PSP_WEAPON remains the
// hidden M1 controller; the left clone mirrors its live weapon frames, while
// the right clone runs FireDualRight independently when M2 is pressed.
// Hellfire uses the Rocket Launcher sprite family at reduced HUD/drop scale.
// ============================================================================

version "4.14"

// Custom PSprite layer used for dual-wielded/recycled weapon sprites.
const TLH_DUAL_MIRROR_LAYER = 2; // left-hand animated mirror
const TLH_DUAL_SECOND_LAYER = 3; // independent M2 weapon PSprite; PSP_WEAPON (1) remains the M1 controller
const TLH_DUAL_HAND_SPREAD = 56.0; // Visible spacing from the screen center for each hand.
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

// The Last Hope gameplay modes. The selector is a server CVar so gameplay
// rules remain authoritative and synchronized in multiplayer. It is defined
// in the companion CVARINFO lump as "tlh_gamemode".
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
// v47.0: sprint stamina, directional dash, momentum slide, coyote jump and air control.
// v48.0: class-agnostic Dual Wield controller using a shared state contract.
// v48.1: +user1/+user2/+user3 were incorrectly routed through no-activator
// network events and received by NetworkProcess, so the actions never ran.
// v48.2: read BT_USER1/2/3 directly from player.cmd.buttons in TacticalPlayer.Tick;
// edge detection uses player.oldbuttons and Dual Wield has an independent cooldown.
// v48.3: reuse the null-checked TacticalPlayer pointer in the SSG HUD branch.
// v49.0: enable WRF_ALLOWUSER3 and native User3 state on four existing weapons;
// remove M4A1 from the compatibility set and implement cylinder-aware ServiceRevolver dual fire.
// v49.1: replace String-valued ternaries passed to ResolveState with explicit
// StateLabel branches, and return ResolveState(null) from the ServiceRevolver ready shim.
// v50.0: initial render-only mirror architecture. It is superseded by the
// independent M2 PSprite firing route added in v52.21.1.
// +user3 is edge-latched until release; the player owns the entrance/exit animation.
// v50.0.1: keep overlay ownership inside TacticalPlayer and apply the full
// offscreen-to-right displacement after ordinary procedural sway clamping.
// v50.0.2: remove the obsolete third motion channel and align mirrored flash,
// palette, interpolation and pivot flags with the live primary PSprite.
// v51.0: route +user3 through InputProcess -> SendNetworkCommand ->
// NetworkCommandProcess. Dual Wield no longer depends on weapon-native User3 states
// or WRF_ALLOWUSER3; only the inert mirror holder and weapon firing routines remain.
// v51.0.1: print an explicit ENABLED/DISABLED confirmation when the command arrives.
// v51.0.2: copy the primary PSprite interpolation marker after mirroring its offsets.
// v52.1: add per-map Simple Rifle kill progression and automatic Blue mode at 60 kills;
// v52.2: resolve ambiguous weapon-state self references with explicit invoker.Owner;
// v52.3: use a class-typed palette default lookup and keep Blue unlock progress in the HUD handler so it survives respawn.
// v52.5: scope SimpleRifle PSprite states explicitly as weapon states to disambiguate action self.
// v52.7: remove the invalid default-class tint lookup and apply the named BlueSimpleRifle TRNSLATE directly to PSprites.
// v52.8: make HUD recoil scaling a four-tic shot pulse; stage Dual Wield with primary-right slide followed by offhand rise.
// v52.10: route the primary-hand shift through each compatible weapon's
// authored overlay/weapon offset actions so every state preserves the left-hand primary placement.
// v52.11: inline the blend calculation in the action wrappers.
// v52.12: use player.mo/self-owner and invoker-weapon explicitly inside weapon actions, avoiding ambiguous Owner lookups.
// v52.19: add independent left/right firing routes to Heavy Chaingun, Rocket Launcher and AMR-99;
// repair the SSG's legacy pistol-like Dual Wield route to fire proper shotgun shells.
// v52.20.5: advance weapon gait in player Tick, strengthen camera/movement sway, and replace the original-visible Dual Wield with a lower-then-two-clone entrance.
// v52.20.4: refine movement, look, inertia and gait sway with tighter limits; authored scale remains unchanged.
// v52.21: restore expressive universal first-person weapon motion, including
// movement inertia, gait, firing/landing/damage springs and wider motion bounds.
// v52.24: make Dual Wield a persistent boolean toggle; remove all blend/duration timers.
// v52.25: automatically release Dual Wield when a different weapon is queued for selection.
// Gore controls: local enable, intensity up/down and palette cycle; extra blood particles only.
// v52.20.1: restore missing semicolons on frame-only state lines after removing overlay actions.
// v52.8: make HUD recoil scaling a four-tic shot pulse; stage Dual Wield with primary-right slide followed by offhand rise.
// v52.6: keep the pickup Spawn sequence in an Actor-scoped state block; keep HUD/weapon actions in Weapon scope.
// v52.4: show the full BLUE SIMPLE RIFLE name in the compact weapon HUD after unlock.
// apply a dedicated electric-blue palette translation to the active Simple Rifle PSprite.
// Blue mode consumes Cell ammo and uses a cyan MarineRailgun-style A_RailAttack.
// Add a continuously refreshed tactical minimap and lightweight screen-space pseudo-shader overlays.
// TacticalM4A1 returns to its stock ZHGG sprite placement without procedural HUD sway/scale/rotation.
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

// Small client-visible gore droplets. Their count, scale and palette are
// controlled by the local player's TLH gore settings.
class TLHGoreParticle : Actor
{
    Default
    {
        Radius 1;
        Height 1;
        Speed 0;
        Gravity 0.55;
        +NOBLOCKMAP
        +NOINTERACTION
        +DONTSPLASH
        RenderStyle "Translucent";
        Alpha 0.88;
        Scale 0.28;
    }

    States
    {
    Spawn:
        BLUD ABC 3;
        TNT1 A 2;
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

class BlueGaussSlug : GaussSlug
{
    Default
    {
        // Preserve the Railgun slug's exact behavior; only recolor its green energy ramp.
        Translation "112:127=192:207";
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
        MISL B 10 Bright
        {
            A_Explode(500, 512);
            A_StartSound("cyber/death", CHAN_BODY);
            A_Quake(8, 25, 0, 1000);
        }
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
        Damage 5;
        Scale 1.2;
        RenderStyle "Add";
    }

    States
    {
    Spawn:
        PLSS A 0 A_StartSound("vile/active", CHAN_WEAPON, CHANF_DEFAULT, 0.2);
        PLSS AB 2 Bright
        {
            A_RadiusThrust(-500, 256, RTF_NOIMPACTDAMAGE);
        }
        Loop;
    Death:
        PLSE ABCDE 4 Bright;
        Stop;
    }
}

class EMPPlasma : PlasmaBall
{
    Default
    {
        Speed 35;
        Damage 10;
        RenderStyle "Add";
        Alpha 0.9;
    }

    States
    {
    Spawn:
        PLSS AB 1 Bright;
        Loop;
    Death:
        PLSE A 2 Bright
        {
            A_Explode(40, 96);
            A_StartSound("weapons/bfgf", CHAN_WEAPON);
            A_Quake(2, 5, 0, 300);
        }
        PLSE BCDE 2 Bright;
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
        Damage 100;
        +RIPPER
        RenderStyle "Add";
        Scale 0.5;
    }

    States
    {
    Spawn:
        BFS1 AB 1 Bright;
        Loop;
    Death:
        BFE1 ABCDEF 3 Bright;
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
    }

    States
    {
    Spawn:
        BFS1 AB 5 Bright;
        Loop;
    Death:
        BFE1 ABCDEF 6 Bright;
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
        PUNG A 0
        {
            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
        }
        PUNG A 1
        {
            A_OverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;
    Deselect:
        PUNG A 1 A_Lower;
        Loop;
    Select:
        PUNG A 1 A_Raise;
        Loop;
    Fire:
        PUNG B 3;
        PUNG C 3
        {
            A_CustomPunch(20, TRUE, CPF_PULLIN, "BulletPuff", 64, 0, 0, "ArmorBonus", "weapons/melee");
            A_SetPitch(pitch - 1.0, SPF_INTERPOLATE);
        }
        PUNG D 4;
        PUNG C 3;
        PUNG B 4 A_ReFire;
        Goto Ready;
    AltFire:
        PUNG B 4
        {
            
            A_StartSound("skeleton/swing", CHAN_WEAPON);
        }
        PUNG C 3
        {
            A_CustomPunch(90, TRUE, CPF_PULLIN, "BulletPuff", 80, 0, 0, "ArmorBonus", "weapons/melee");
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            A_Quake(2, 5, 0, 100);
        }
        PUNG D 8;
        PUNG C 4;
        PUNG B 5;
        Goto Ready;
    Zoom:
        PUNG B 5;
        PUNG C 5
        {
            A_Explode(80, 128, XF_NOTMISSILE);
            A_StartSound("cyber/hoof", CHAN_BODY);
            A_SetPitch(pitch + 4.0, SPF_INTERPOLATE);
            A_Quake(3, 8, 0, 200);
        }
        PUNG D 10;
        Goto Ready;
    Reload:
        PUNG B 2 A_StartSound("vile/sight", CHAN_BODY);
        PUNG C 8
        {
            A_RadiusThrust(800, 192, RTF_NOIMPACTDAMAGE);
            A_SetPitch(pitch - 2.0, SPF_INTERPOLATE);
        }
        PUNG D 8;
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
            A_OverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
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
            
            A_SetPitch(pitch - 0.5, SPF_INTERPOLATE);
        }
        SAWG B 4
        {
            A_Saw();
            
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
        SAWG A 1 { A_Saw();  A_SetPitch(pitch - 1.0, SPF_INTERPOLATE); }
        SAWG B 1 { A_Saw();  A_SetPitch(pitch + 1.0, SPF_INTERPOLATE); }
        SAWG A 1 { A_Saw();  A_SetPitch(pitch - 1.0, SPF_INTERPOLATE); }
        SAWG B 1 { A_Saw();  A_SetPitch(pitch + 1.0, SPF_INTERPOLATE); }
        SAWG C 15;
        Goto Ready;
    Spawn:
        CSAW A -1;
        Stop;
    }

}

class RecoilPistol : Pistol replaces Pistol
{
    // State-action wrappers calculate the slide directly from the owning
    // player. Do not call a normal Weapon member helper from an action method:
    // GZDoom gives those calls different self contexts during state execution.
    action void A_TLHDualWeaponOffset(double wx, double wy, int flags = 0)
    {
        // In a weapon action, self is the player pawn and invoker is this weapon.
        TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
        Weapon dualWeapon = Weapon(invoker);
        if (tlhPlayer && tlhPlayer.tlhDualWieldWeapon == dualWeapon)
        {
            double slide = tlhPlayer.GetTLHDualPrimarySlide();
            wx -= 36.0 * slide;
        }
        A_WeaponOffset(wx, wy, flags);
    }

    action void A_TLHDualOverlayOffset(int layer, double wx, double wy, int flags = 0)
    {
        if (layer == PSP_WEAPON)
        {
            TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
            Weapon dualWeapon = Weapon(invoker);
            bool dualPresentation = tlhPlayer &&
                tlhPlayer.tlhDualWieldWeapon == dualWeapon &&
                tlhPlayer.tlhDualWieldActive;

            if (dualPresentation)
                wx -= 36.0 * tlhPlayer.GetTLHDualPrimarySlide();
        }
        A_OverlayOffset(layer, wx, wy, flags);
    }



    bool fullAuto;
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

    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        TacticalPlayer tlhPlayer = TacticalPlayer(Owner);
        bool dualActive = tlhPlayer && tlhPlayer.tlhDualWieldActive;
        if (dualActive && fireMode == AltFire)
        {
            bool infinite = sv_infiniteammo ||
                (Owner && Owner.FindInventory("PowerInfiniteAmmo", true));
            if (!requireAmmo || infinite) return true;
            return Owner && Owner.CountInv("Clip") >= 1;
        }

        return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, ammocount);
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        PISG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.92, 0.92);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PISG A 1
        {
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;


    DualMirrorHold:
        TNT1 A -1;
        Stop;

    Deselect:
        PISG A 0
        {
            A_OverlayRotate(PSP_WEAPON, 0);
            A_OverlayAlpha(PSP_WEAPON, 1.0);
            A_Lower();
        }
        Loop;

    Select:
        PISG A 0
        {
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
        PISG A 2 A_TLHDualWeaponOffset(0, 36, WOF_INTERPOLATE);
        PISG A 2 A_TLHDualWeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;


    Fire:
        PISG A 0
        {
            if (TacticalPlayer(player.mo) && TacticalPlayer(player.mo).tlhDualWieldActive)
                return ResolveState("Ready");

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
        PISG C 3;
        PISG B 3;
        Goto Ready;

    FireAuto:
        PISG B 2
        {
            A_GunFlash();
            A_FirePistol();
            A_SetPitch(pitch - 0.8, SPF_INTERPOLATE);
        }
        PISG C 2;
        PISG A 0 A_ReFire;
        Goto Ready;

    FireDualLeft:
        PISG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("Clip") < 1)
                return ResolveState("DualMirrorHold");

            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            let mo = player.mo;
            if (mo)
            {
                double shotAngle = angle + FRandom(-3.0, 3.0);
                double shotPitch = pitch + FRandom(-1.5, 1.5);
                mo.LineAttack(shotAngle, 2048, shotPitch, 7, "Normal", "BulletPuff", 0, null, 0, 0, -22.0);
            }
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 0.55, SPF_INTERPOLATE);
            
            return ResolveState(null);
        }
        PISG B 2;
        PISG A 0
        {
            if (invoker.fullAuto && (player.cmd.buttons & BT_ATTACK))
                return ResolveState("FireDualLeft");
            return ResolveState("DualMirrorHold");
        }

    FireDualRight:
        PISG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("Clip") < 1)
                return ResolveState("DualMirrorHold");

            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            let mo = player.mo;
            if (mo)
            {
                double shotAngle = angle + FRandom(-3.0, 3.0);
                double shotPitch = pitch + FRandom(-1.5, 1.5);
                mo.LineAttack(shotAngle, 2048, shotPitch, 7, "Normal", "BulletPuff", 0, null, 0, 0, 22.0);
            }
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 0.55, SPF_INTERPOLATE);
            
            return ResolveState(null);
        }
        PISG B 2;
        PISG A 0
        {
            if (invoker.fullAuto && (player.cmd.buttons & BT_ALTATTACK))
                return ResolveState("FireDualRight");
            return ResolveState("DualMirrorHold");
        }

    AltFire:
        PISG A 0
        {
            if (TacticalPlayer(player.mo) && TacticalPlayer(player.mo).tlhDualWieldActive)
                return ResolveState("Ready");

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
    // State-action wrappers calculate the slide directly from the owning
    // player. Do not call a normal Weapon member helper from an action method:
    // GZDoom gives those calls different self contexts during state execution.
    action void A_TLHDualWeaponOffset(double wx, double wy, int flags = 0)
    {
        // In a weapon action, self is the player pawn and invoker is this weapon.
        TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
        Weapon dualWeapon = Weapon(invoker);
        if (tlhPlayer && tlhPlayer.tlhDualWieldWeapon == dualWeapon)
        {
            double slide = tlhPlayer.GetTLHDualPrimarySlide();
            wx -= 36.0 * slide;
        }
        A_WeaponOffset(wx, wy, flags);
    }

    action void A_TLHDualOverlayOffset(int layer, double wx, double wy, int flags = 0)
    {
        if (layer == PSP_WEAPON)
        {
            TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
            Weapon dualWeapon = Weapon(invoker);
            bool dualPresentation = tlhPlayer &&
                tlhPlayer.tlhDualWieldWeapon == dualWeapon &&
                tlhPlayer.tlhDualWieldActive;

            if (dualPresentation)
                wx -= 36.0 * tlhPlayer.GetTLHDualPrimarySlide();
        }
        A_OverlayOffset(layer, wx, wy, flags);
    }



    int weaponMode;
    bool fullAuto;
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

    }

    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        TacticalPlayer tlhPlayer = TacticalPlayer(Owner);
        bool dualActive = tlhPlayer && tlhPlayer.tlhDualWieldActive;
        if (dualActive && fireMode == AltFire)
        {
            bool infinite = sv_infiniteammo ||
                (Owner && Owner.FindInventory("PowerInfiniteAmmo", true));
            if (!requireAmmo || infinite) return true;
            return Owner && Owner.CountInv("Clip") >= 1;
        }

        return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, ammocount);
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        PISG A 0
        {
            if (invoker.weaponMode == 1)
                return ResolveState("ReadyLauncher");

            A_OverlayScale(PSP_WEAPON, 0.78, 0.88);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, false);
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PISG A 1
        {
            A_TLHDualWeaponOffset(0, 32, WOF_INTERPOLATE);
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;


    ReadyLauncher:
        PISG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.68, 0.88);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, false);
        }
        PISG A 1
        {
            A_TLHDualWeaponOffset(0, 32, WOF_INTERPOLATE);
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;


    DualMirrorHold:
        TNT1 A -1;
        Stop;

    Deselect:
        PISG A 0
        {
            invoker.weaponMode = 0;
            A_OverlayRotate(PSP_WEAPON, 0);
            A_OverlayAlpha(PSP_WEAPON, 1.0);
        }
        PISG A 1 A_Lower;
        Loop;

    Select:
        PISG A 0
        {
            invoker.weaponMode = 0;
        }
        PISG A 1 A_Raise;
        Loop;

    Fire:
        PISG A 0
        {
            if (TacticalPlayer(player.mo) && TacticalPlayer(player.mo).tlhDualWieldActive)
                return ResolveState("Ready");

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
            
            A_FireBullets(2.0, 0, 1, 8, "BulletPuff");
            A_SetPitch(pitch - 2.0, SPF_INTERPOLATE);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_Quake(1, 2, 0, 100);
            
        }
        PISG C 3;
        PISG B 3;
        Goto Ready;

    FireAuto:
        PISG B 3
        {
            A_GunFlash();
            
            A_FireBullets(3.0, 0, 1, 5, "BulletPuff");
            A_SetPitch(pitch - 1.8, SPF_INTERPOLATE);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_Quake(1.8, 3.0, 0, 100);
            
        }
        PISG C 2;
        PISG A 0 A_ReFire;
        Goto Ready;

    FireDualLeft:
        PISG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("Clip") < 1)
                return ResolveState("DualMirrorHold");

            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            let mo = player.mo;
            if (mo)
            {
                double shotAngle = angle + FRandom(-2.8, 2.8);
                double shotPitch = pitch + FRandom(-1.3, 1.3);
                mo.LineAttack(shotAngle, 2048, shotPitch, 8, "Normal", "BulletPuff", 0, null, 0, 0, -20.0);
            }
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 1.8, SPF_INTERPOLATE);
            A_Quake(1.2, 2.0, 0, 80);
            
            return ResolveState(null);
        }
        PISG B 2;
        PISG A 0
        {
            if (invoker.fullAuto && (player.cmd.buttons & BT_ATTACK))
                return ResolveState("FireDualLeft");
            return ResolveState("DualMirrorHold");
        }

    FireDualRight:
        PISG A 0
        {
            if (!(sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) && player.mo.CountInv("Clip") < 1)
                return ResolveState("DualMirrorHold");

            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            let mo = player.mo;
            if (mo)
            {
                double shotAngle = angle + FRandom(-2.8, 2.8);
                double shotPitch = pitch + FRandom(-1.3, 1.3);
                mo.LineAttack(shotAngle, 2048, shotPitch, 8, "Normal", "BulletPuff", 0, null, 0, 0, 20.0);
            }
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 1.8, SPF_INTERPOLATE);
            A_Quake(1.2, 2.0, 0, 80);
            
            return ResolveState(null);
        }
        PISG B 2;
        PISG A 0
        {
            if (invoker.fullAuto && (player.cmd.buttons & BT_ALTATTACK))
                return ResolveState("FireDualRight");
            return ResolveState("DualMirrorHold");
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
            
        }
        PISG C 5;
        PISG A 5 A_ReFire;
        Goto ReadyLauncher;

    AltFire:
        PISG A 0
        {
            if (TacticalPlayer(player.mo) && TacticalPlayer(player.mo).tlhDualWieldActive)
                return ResolveState("Ready");

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
        PISG A 2 A_TLHDualWeaponOffset(0, 42, WOF_INTERPOLATE);
        PISG A 2 A_TLHDualWeaponOffset(0, 36, WOF_INTERPOLATE);
        Goto Ready;


    Zoom:
        PISG A 0
        {
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
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 44, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -1.0);
        }
        PISG A 3
        {
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 52, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -2.0);
        }
        PISG A 0
        {
            invoker.weaponMode = 1;
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 42, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PISG A 3
        {
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE);
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
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 44, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 1.0);
        }
        PISG A 3
        {
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 52, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 2.0);
        }
        PISG A 0
        {
            invoker.weaponMode = 0;
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 42, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PISG A 3
        {
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 35, WOF_INTERPOLATE);
        }
        Goto Ready;

    Flash:
        PISF A 3 Bright A_Light1;
        PISF B 3 Bright A_Light2;
        Goto LightDone;

    Spawn:
        // Vanilla GZDoom pistol pickup (PIST A / PISTA0).
        // Procedural touch only: a restrained 1.5% scale pulse, preserving
        // the original pickup silhouette and using the class translation.
        PIST A 1
        {
            double pickupPulse = 1.0 + sin(double(level.time) * 0.02 * TLH_RAD_TO_DEG) * 0.015;
            A_SetScale(pickupPulse, pickupPulse);
        }
        Loop;
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
            A_OverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
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
            
            A_FireShotgun();
            A_SetPitch(pitch - 2.0, SPF_INTERPOLATE);
        }
        SHTG BC 5;
        SHTG D 4;
        SHTG CB 5;
        SHTG A 3;
        SHTG A 7 {  A_ReFire(); }
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
    // State-action wrappers calculate the slide directly from the owning
    // player. Do not call a normal Weapon member helper from an action method:
    // GZDoom gives those calls different self contexts during state execution.
    action void A_TLHDualWeaponOffset(double wx, double wy, int flags = 0)
    {
        // In a weapon action, self is the player pawn and invoker is this weapon.
        TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
        Weapon dualWeapon = Weapon(invoker);
        if (tlhPlayer && tlhPlayer.tlhDualWieldWeapon == dualWeapon)
        {
            double slide = tlhPlayer.GetTLHDualPrimarySlide();
            wx -= 36.0 * slide;
        }
        A_WeaponOffset(wx, wy, flags);
    }

    action void A_TLHDualOverlayOffset(int layer, double wx, double wy, int flags = 0)
    {
        if (layer == PSP_WEAPON)
        {
            TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
            Weapon dualWeapon = Weapon(invoker);
            bool dualPresentation = tlhPlayer &&
                tlhPlayer.tlhDualWieldWeapon == dualWeapon &&
                tlhPlayer.tlhDualWieldActive;

            if (dualPresentation)
                wx -= 36.0 * tlhPlayer.GetTLHDualPrimarySlide();
        }
        A_OverlayOffset(layer, wx, wy, flags);
    }



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

    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        TacticalPlayer tlhPlayer = TacticalPlayer(Owner);
        bool dualActive = tlhPlayer && tlhPlayer.tlhDualWieldActive;
        if (dualActive &&
            (fireMode == PrimaryFire || fireMode == AltFire))
        {
            bool infinite = sv_infiniteammo ||
                (Owner && Owner.FindInventory("PowerInfiniteAmmo", true));
            if (!requireAmmo || infinite) return true;
            return Owner && Owner.CountInv("Shell") >= 2;
        }

        return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, ammocount);
    }

    States
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        SHT2 A 0
        {
            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        SHT2 A 1
        {
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;

    Reload:
        SHT2 A 0
        {
            if (invoker.dragonBreath)
                return ResolveState("SetBuckshot");

            return ResolveState("SetDragon");
        }
        SHT2 A 2 A_TLHDualWeaponOffset(0, 36, WOF_INTERPOLATE);
        SHT2 A 2 A_TLHDualWeaponOffset(0, 42, WOF_INTERPOLATE);
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
        SHT2 A 2 A_TLHDualWeaponOffset(0, 36, WOF_INTERPOLATE);
        SHT2 A 2 A_TLHDualWeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;


    FireDualLeft:
        SHT2 A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && (!player.mo || player.mo.CountInv("Shell") < 2))
                return ResolveState("DualMirrorHold");
            A_TakeInventory("Shell", 2, TIF_NOTAKEINFINITE);
            if (invoker.dragonBreath)
            {
                for (int i = 0; i < 13; i++)
                    A_FireProjectile("DragonBreathFire", random(-10, 10),
                        false, 0, 0, 0, random(-5, 5));
                A_StartSound("vile/firestrt", CHAN_BODY);
            }
            else if (player.mo)
            {
                for (int pellet = 0; pellet < 20; pellet++)
                    player.mo.LineAttack(angle + FRandom(-11.2, 11.2), 2048,
                        pitch + FRandom(-7.1, 7.1), 5, "Normal", "BulletPuff",
                        0, null, 0, 0, -22.0);
            }
            A_StartSound("weapons/sshotf", CHAN_WEAPON);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            A_Quake(3, 5, 0, 100);
            return ResolveState(null);
        }
        SHT2 B 3;
        SHT2 A 0
        {
            if (player.cmd.buttons & BT_ATTACK) return ResolveState("FireDualLeft");
            return ResolveState("DualMirrorHold");
        }

    FireDualRight:
        SHT2 A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && (!player.mo || player.mo.CountInv("Shell") < 2))
                return ResolveState("DualMirrorHold");
            A_TakeInventory("Shell", 2, TIF_NOTAKEINFINITE);
            if (invoker.dragonBreath)
            {
                for (int i = 0; i < 13; i++)
                    A_FireProjectile("DragonBreathFire", random(-10, 10),
                        false, 0, 0, 0, random(-5, 5));
                A_StartSound("vile/firestrt", CHAN_BODY);
            }
            else if (player.mo)
            {
                for (int pellet = 0; pellet < 20; pellet++)
                    player.mo.LineAttack(angle + FRandom(-11.2, 11.2), 2048,
                        pitch + FRandom(-7.1, 7.1), 5, "Normal", "BulletPuff",
                        0, null, 0, 0, 22.0);
            }
            A_StartSound("weapons/sshotf", CHAN_WEAPON);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            A_Quake(3, 5, 0, 100);
            return ResolveState(null);
        }
        SHT2 B 3;
        SHT2 A 0
        {
            if (player.cmd.buttons & BT_ALTATTACK) return ResolveState("FireDualRight");
            return ResolveState("DualMirrorHold");
        }

    // Retained compatibility state for old save-state references.
    Fire:
        SHT2 A 0
        {
            if (TacticalPlayer(player.mo) && TacticalPlayer(player.mo).tlhDualWieldActive)
                return ResolveState("Ready");

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
            A_StartSound("weapons/sshotf", CHAN_WEAPON);
            A_StartSound("vile/firestrt", CHAN_BODY);
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
            if (TacticalPlayer(player.mo) && TacticalPlayer(player.mo).tlhDualWieldActive)
                return ResolveState("Ready");

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
        SHT2 A 0;
        Goto Ready;

    DualMirrorHold:
        TNT1 A -1;
        Stop;

    Deselect:
        SHT2 A 0
        {
        }
        SHT2 A 1 A_Lower;
        Loop;

    Select:
        SHT2 A 0
        {
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
            A_OverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
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

// ==========================================
// HeavyChaingun is the only custom chaingun class in TLH.
// It uses only the original DOOM II chaingun sprites: CHGG, CHGF and MGUN.
// The stock Chaingun class remains available separately.
// ============================================================================
/* HEAVY CHAINGUN
   Keeps the former TLH tactical-chaingun heat/overheat mechanics and fire-mode toggle, using only original DOOM II sprites: HUD CHGG A/B, flash CHGF A/B, pickup MGUN A.
   M4A1 keeps its separate ZHGG/ZGUN sprites.
 */
class HeavyChaingun : DoomWeapon
{

    // Procedural left-hand slide; the render-only mirror flips this live offset.
    action void A_TLHDualWeaponOffset(double wx, double wy, int flags = 0)
    {
        TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
        Weapon dualWeapon = Weapon(invoker);
        if (tlhPlayer && tlhPlayer.tlhDualWieldWeapon == dualWeapon)
            wx -= 36.0 * tlhPlayer.GetTLHDualPrimarySlide();
        A_WeaponOffset(wx, wy, flags);
    }

    action void A_TLHDualOverlayOffset(int layer, double wx, double wy, int flags = 0)
    {
        if (layer == PSP_WEAPON)
        {
            TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
            Weapon dualWeapon = Weapon(invoker);
            bool dualPresentation = tlhPlayer &&
                tlhPlayer.tlhDualWieldWeapon == dualWeapon &&
                tlhPlayer.tlhDualWieldActive;

            if (dualPresentation)
                wx -= 36.0 * tlhPlayer.GetTLHDualPrimarySlide();
        }
        A_OverlayOffset(layer, wx, wy, flags);
    }

    bool burstMode;
    bool gatlingMode;
    bool gatlingSpunUp;
    int heat;
    bool overheated;
    bool warningShown;
    bool criticalShown;

    const MaxHeat = 300;
    const RecoverHeat = 45;
    const WarmHeat = 180;
    const CriticalHeat = 250;


    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        TacticalPlayer tlhPlayer = TacticalPlayer(Owner);
        if (tlhPlayer && tlhPlayer.tlhDualWieldActive &&
            tlhPlayer.tlhDualWieldWeapon == self &&
            (fireMode == PrimaryFire || fireMode == AltFire))
        {
            bool infinite = sv_infiniteammo ||
                (Owner && Owner.FindInventory("PowerInfiniteAmmo", true));
            if (!requireAmmo || infinite) return true;
            return Owner && Owner.CountInv("Clip") >= 1;
        }
        return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, ammocount);
    }

    override void Tick()
    {
        // Preserve the parent weapon/actor tick even while the weapon has no owner.
        Super.Tick();

        // Inventory weapons can briefly exist before an owner/player is assigned.
        // Do not access player state until both references are valid.
        if (!Owner || !Owner.player) return;

        bool firing = (Owner.player.ReadyWeapon == self &&
            (Owner.player.cmd.buttons & BT_ATTACK));

        if (overheated) heat -= 3;
        else if (!firing && heat > 0) heat -= 2;

        if (heat < 0) heat = 0;
        if (warningShown && heat <= 76) warningShown = false;
        if (criticalShown && heat <= 112) criticalShown = false;
        if (overheated && heat <= RecoverHeat) overheated = false;
    }

Default
    {
        Weapon.SlotNumber 4;
        Weapon.SlotPriority 4.8;
        Weapon.SelectionOrder 410;
        Weapon.AmmoType1 "Clip";
        Weapon.AmmoUse1 1;
        Weapon.AmmoGive1 40;
        Weapon.AmmoType2 "RocketAmmo";
        Weapon.AmmoUse2 1;
        Weapon.AmmoGive2 4;
        Weapon.Kickback 160;
        Inventory.PickupMessage "Picked up the Heavy Chaingun.";

    }

    States
    {
    Ready:
        CHGG A 0
        {
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32, 0);
            if (invoker.gatlingSpunUp &&
                (!player || !(player.cmd.buttons & BT_ATTACK)))
                return ResolveState("GatlingSpinDown");
            return ResolveState(null);
        }
        CHGG A 1 A_WeaponReady(WRF_ALLOWRELOAD);
        Loop;

    Deselect:
        // Keep the chosen fire mode when switching weapons, but stop the
        // barrel spin so it cannot remain latched across weapon changes.
        CHGG A 1
        {
            if (invoker.gatlingSpunUp)
            {
                invoker.gatlingSpunUp = false;
                A_StartSound("weapons/sawidle", CHAN_WEAPON);
            }
            A_Lower();
        }
        Loop;

    Select:
        CHGG A 1 A_Raise();
        Loop;

    Reload:
        CHGG A 0
        {
            if (invoker.overheated)
                return ResolveState("ManualVent");

            // R cycles: Full Auto -> Burst -> Gatling -> Full Auto.
            if (invoker.gatlingMode)
                return ResolveState("SetAuto");
            if (invoker.burstMode)
                return ResolveState("SetGatling");
            return ResolveState("SetBurst");
        }

    SetBurst:
        CHGG A 2;
        CHGG A 4
        {
            invoker.burstMode = true;
            invoker.gatlingMode = false;
            invoker.gatlingSpunUp = false;
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Print("HEAVY CHAINGUN | FIRE MODE CHANGED: 3-ROUND BURST");
        }
        CHGG A 2;
        Goto Ready;

    SetAuto:
        CHGG A 2 A_TLHDualWeaponOffset(0, 37, WOF_INTERPOLATE);
        CHGG A 4
        {
            if (invoker.gatlingMode && invoker.gatlingSpunUp)
                A_StartSound("weapons/sawidle", CHAN_WEAPON);
            invoker.burstMode = false;
            invoker.gatlingMode = false;
            invoker.gatlingSpunUp = false;
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
            A_Print("HEAVY CHAINGUN | FIRE MODE CHANGED: FULL AUTO");
        }
        CHGG A 2 A_TLHDualWeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    SetGatling:
        CHGG A 2 A_TLHDualWeaponOffset(0, 37, WOF_INTERPOLATE);
        CHGG A 4
        {
            invoker.burstMode = false;
            invoker.gatlingMode = true;
            invoker.gatlingSpunUp = false;
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            A_Print("HEAVY CHAINGUN | FIRE MODE CHANGED: GATLING (SPIN-UP)");
        }
        CHGG A 2 A_TLHDualWeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    ManualVent:
        CHGG A 4
        {
            int oldHeat = invoker.heat;
            invoker.heat -= 55;
            if (invoker.heat < 0) invoker.heat = 0;
            A_StartSound("weapons/sawidle", CHAN_WEAPON);
            A_Print(String.Format("HEAVY CHAINGUN: VENTING %d -> %d", oldHeat, invoker.heat));
        }
        CHGG A 5;
        Goto Ready;

    Fire:
        CHGG A 0
        {
            TacticalPlayer dualPlayer = TacticalPlayer(player.mo);
            if (dualPlayer && dualPlayer.tlhDualWieldActive &&
                dualPlayer.tlhDualWieldWeapon == invoker)
                return ResolveState("Ready");
            if (invoker.overheated)
                return ResolveState("Overheated");

            if (invoker.heat >= MaxHeat)
            {
                invoker.overheated = true;
                A_StartSound("weapons/sshotl", CHAN_WEAPON);
                A_Print("HEAVY CHAINGUN: OVERHEATED - VENTING");
                return ResolveState("Overheated");
            }

            if (invoker.heat >= CriticalHeat && !invoker.criticalShown)
            {
                invoker.criticalShown = true;
                A_StartSound("weapons/sshotc", CHAN_WEAPON);
                A_Print("HEAVY CHAINGUN: CRITICAL HEAT");
            }
            else if (invoker.heat >= WarmHeat && !invoker.warningShown)
            {
                invoker.warningShown = true;
                A_StartSound("weapons/sshotc", CHAN_WEAPON);
                A_Print("HEAVY CHAINGUN: BARREL HOT");
            }

            // Gatling maintains its own fast cadence and handles heat through
            // the shared warning/overheat gates above.
            if (invoker.gatlingMode)
            {
                if (invoker.gatlingSpunUp)
                    return ResolveState("GatlingFire");
                return ResolveState("GatlingSpinUp");
            }

            if (invoker.heat >= CriticalHeat)
                return ResolveState("FireHot");
            if (invoker.heat >= WarmHeat)
                return ResolveState("FireWarm");

            // Keep weapon selection/Ready independent from the custom burst logic.
            // Only enter a three-shot burst when the reserve can support the volley.
            if (invoker.burstMode)
            {
                bool infiniteAmmo = sv_infiniteammo ||
                    (player && player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

                if (!infiniteAmmo &&
                    (!player || !player.mo || player.mo.CountInv("Clip") < 3))
                    return ResolveState("Ready");

                return ResolveState("BurstFire");
            }

            return ResolveState(null);
        }
        CHGG A 2
        {
            A_FireBullets(3.0, 3.0, 1, 15, "BulletPuff");
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            // Camera kick only; A_Recoil would physically push the player backward.
            A_SetPitch(pitch - 0.55, SPF_INTERPOLATE);
            A_Quake(0, 1, 0, 35);
            invoker.heat += invoker.heat >= WarmHeat ? 3 : 2;
            if (invoker.heat > MaxHeat) invoker.heat = MaxHeat;
        }
        CHGG B 1;
        CHGG A 0 A_ReFire;
        Goto Ready;

    BurstFire:
        CHGG A 1
        {
            A_FireBullets(2.5, 2.5, 1, 15, "BulletPuff");
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_SetPitch(pitch - 0.65, SPF_INTERPOLATE);
            invoker.heat += 2;
            if (invoker.heat > MaxHeat) invoker.heat = MaxHeat;
        }
        CHGG B 1;
        CHGG A 1
        {
            A_FireBullets(2.5, 2.5, 1, 15, "BulletPuff");
            A_SetPitch(pitch - 0.65, SPF_INTERPOLATE);
            invoker.heat += 2;
            if (invoker.heat > MaxHeat) invoker.heat = MaxHeat;
        }
        CHGG B 1;
        CHGG A 1
        {
            A_FireBullets(2.5, 2.5, 1, 15, "BulletPuff");
            A_SetPitch(pitch - 0.65, SPF_INTERPOLATE);
            invoker.heat += 2;
            if (invoker.heat > MaxHeat) invoker.heat = MaxHeat;
        }
        CHGG B 4;
        Goto Ready;

    // Gatling takes a short moment to spool up, then fires faster than Full Auto.
    // The first shot uses the ammo already consumed by entering Fire; A_ReFire
    // returns through Fire for subsequent shots so normal ammo checks stay intact.
    GatlingSpinUp:
        CHGG A 3 A_StartSound("weapons/sawup", CHAN_WEAPON);
        CHGG B 3;
        CHGG A 1
        {
            bool infiniteAmmo = sv_infiniteammo ||
                (player && player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (!player || !player.mo || !(player.cmd.buttons & BT_ATTACK))
            {
                // Cancelled spool-up: refund the round that Fire reserved.
                if (!infiniteAmmo)
                    A_GiveInventory("Clip", 1);
                invoker.gatlingSpunUp = false;
                return ResolveState("GatlingSpinDown");
            }

            invoker.gatlingSpunUp = true;
            A_FireBullets(3.0, 3.0, 1, 15, "BulletPuff");
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_SetPitch(pitch - 0.65, SPF_INTERPOLATE);
            A_Quake(0, 1, 0, 35);

            invoker.heat += 4;
            if (invoker.heat > MaxHeat) invoker.heat = MaxHeat;
            if (invoker.heat >= MaxHeat)
            {
                invoker.overheated = true;
                A_StartSound("weapons/sshotl", CHAN_WEAPON);
                A_Print("HEAVY CHAINGUN: OVERHEATED - VENTING");
                return ResolveState("Overheated");
            }
            return ResolveState(null);
        }
        CHGG B 1;
        CHGG A 0 A_ReFire;
        Goto Ready;

    GatlingFire:
        CHGG A 1
        {
            if (!player || !player.mo || !(player.cmd.buttons & BT_ATTACK))
                return ResolveState("GatlingSpinDown");

            A_FireBullets(3.0, 3.0, 1, 15, "BulletPuff");
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_SetPitch(pitch - 0.70, SPF_INTERPOLATE);
            A_Quake(0, 1, 0, 35);
            invoker.heat += 5;
            if (invoker.heat > MaxHeat) invoker.heat = MaxHeat;
            if (invoker.heat >= MaxHeat)
            {
                invoker.overheated = true;
                A_StartSound("weapons/sshotl", CHAN_WEAPON);
                A_Print("HEAVY CHAINGUN: OVERHEATED - VENTING");
                return ResolveState("Overheated");
            }
            return ResolveState(null);
        }
        CHGG B 1;
        CHGG A 0 A_ReFire;
        Goto Ready;

    GatlingSpinDown:
        CHGG B 3;
        CHGG A 2
        {
            invoker.gatlingSpunUp = false;
            A_StartSound("weapons/sawidle", CHAN_WEAPON);
        }
        Goto Ready;

    FireWarm:
        CHGG A 3
        {
            A_FireBullets(3.0, 3.0, 1, 15, "BulletPuff");
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_SetPitch(pitch - 0.75, SPF_INTERPOLATE);
            
            
            invoker.heat += 3;
            if (invoker.heat > MaxHeat) invoker.heat = MaxHeat;
            if (invoker.heat >= MaxHeat)
            {
                invoker.overheated = true;
                A_StartSound("weapons/sshotl", CHAN_WEAPON);
                A_Print("HEAVY CHAINGUN: OVERHEATED - VENTING");
                return ResolveState("Overheated");
            }
            return ResolveState(null);
        }
        CHGG B 1;
        CHGG A 0 A_ReFire;
        Goto Ready;

    FireHot:
        CHGG A 4
        {
            A_FireBullets(3.0, 3.0, 1, 15, "BulletPuff");
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_SetPitch(pitch - 1.0, SPF_INTERPOLATE);
            
            
            invoker.heat += 4;
            if (invoker.heat > MaxHeat) invoker.heat = MaxHeat;
            if (invoker.heat >= MaxHeat)
            {
                invoker.overheated = true;
                A_StartSound("weapons/sshotl", CHAN_WEAPON);
                A_Print("HEAVY CHAINGUN: OVERHEATED - VENTING");
                return ResolveState("Overheated");
            }
            return ResolveState(null);
        }
        CHGG B 1;
        CHGG A 0 A_ReFire;
        Goto Ready;

    Overheated:
        CHGG A 2
        {
            A_WeaponReady(WRF_ALLOWRELOAD | WRF_NOPRIMARY | WRF_NOSECONDARY);
            if (!invoker.overheated || invoker.heat <= RecoverHeat)
            {
                invoker.overheated = false;
                return ResolveState("Ready");
            }
            return ResolveState(null);
        }
        Loop;


    // Each hand fires independently while sharing the weapon's heat pool.
    FireDualLeft:
        CHGG A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (invoker.overheated || invoker.heat >= MaxHeat)
            {
                invoker.overheated = true;
                return ResolveState("DualMirrorHold");
            }
            if (!infinite && (!player.mo || player.mo.CountInv("Clip") < 1))
                return ResolveState("DualMirrorHold");
            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            if (player.mo)
                player.mo.LineAttack(angle + FRandom(-3.0, 3.0), 2048,
                    pitch + FRandom(-2.0, 2.0), 15, "Normal", "BulletPuff",
                    0, null, 0, 0, -22.0);
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_SetPitch(pitch - (invoker.gatlingMode ? 0.70 : 0.55), SPF_INTERPOLATE);
            invoker.heat += invoker.gatlingMode ? 5 : (invoker.heat >= WarmHeat ? 3 : 2);
            if (invoker.heat > MaxHeat) invoker.heat = MaxHeat;
            if (invoker.heat >= MaxHeat)
            {
                invoker.overheated = true;
                A_StartSound("weapons/sshotl", CHAN_WEAPON);
                A_Print("HEAVY CHAINGUN: OVERHEATED - VENTING");
                return ResolveState("DualMirrorHold");
            }
            return ResolveState(null);
        }
        CHGG B 1;
        CHGG A 0
        {
            if (player.cmd.buttons & BT_ATTACK) return ResolveState("FireDualLeft");
            return ResolveState("DualMirrorHold");
        }

    FireDualRight:
        CHGG A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (invoker.overheated || invoker.heat >= MaxHeat)
            {
                invoker.overheated = true;
                return ResolveState("DualMirrorHold");
            }
            if (!infinite && (!player.mo || player.mo.CountInv("Clip") < 1))
                return ResolveState("DualMirrorHold");
            A_TakeInventory("Clip", 1, TIF_NOTAKEINFINITE);
            if (player.mo)
                player.mo.LineAttack(angle + FRandom(-3.0, 3.0), 2048,
                    pitch + FRandom(-2.0, 2.0), 15, "Normal", "BulletPuff",
                    0, null, 0, 0, 22.0);
            A_StartSound("weapons/chngun", CHAN_WEAPON);
            A_SetPitch(pitch - (invoker.gatlingMode ? 0.70 : 0.55), SPF_INTERPOLATE);
            invoker.heat += invoker.gatlingMode ? 5 : (invoker.heat >= WarmHeat ? 3 : 2);
            if (invoker.heat > MaxHeat) invoker.heat = MaxHeat;
            if (invoker.heat >= MaxHeat)
            {
                invoker.overheated = true;
                A_StartSound("weapons/sshotl", CHAN_WEAPON);
                A_Print("HEAVY CHAINGUN: OVERHEATED - VENTING");
                return ResolveState("DualMirrorHold");
            }
            return ResolveState(null);
        }
        CHGG B 1;
        CHGG A 0
        {
            if (player.cmd.buttons & BT_ALTATTACK) return ResolveState("FireDualRight");
            return ResolveState("DualMirrorHold");
        }

    AltFire:
        CHGG B 0
        {
            TacticalPlayer dualPlayer = TacticalPlayer(player.mo);
            if (dualPlayer && dualPlayer.tlhDualWieldActive &&
                dualPlayer.tlhDualWieldWeapon == invoker)
                return ResolveState("Ready");
            return ResolveState(null);
        }
        CHGG B 3
        {
            A_FireProjectile("M203Grenade");
            A_StartSound("weapons/rocklf", CHAN_WEAPON);
            // Heavy launcher kick is camera-only: no horizontal velocity impulse.
            A_SetPitch(pitch - 2.2, SPF_INTERPOLATE);
            A_Quake(1.2, 3.0, 0, 70);
        }
        CHGG A 8;
        Goto Ready;

    DualMirrorHold:
        TNT1 A -1;
        Stop;

    Flash:
        CHGF A 2 Bright A_Light1;
        CHGF B 2 Bright A_Light2;
        Goto LightDone;

    Spawn:
        MGUN A -1;
        Stop;
    }
}

class TacticalM4A1 : DoomWeapon
{
    bool burstMode;
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
        // Three-round burst needs a full three-round reserve.
        if (fireMode == PrimaryFire && burstMode)
            return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, 3);

        return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, ammocount);
    }

    States
    {
    Ready:
        ZHGG A 1 A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        Loop;


    Deselect:
        ZHGG A 1 A_Lower;
        Loop;
    Select:
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
            
            return ResolveState(null);
        }
        ZHGG B 10;
        ZHGG A 15 A_StartSound("weapons/sshotl", CHAN_WEAPON);
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
            A_OverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);

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

            invoker.stability -= invoker.braced ? 1 : 2;
            if (invoker.stability < 45)
                invoker.stability = 45;

            
            
            
            A_SetPitch(pitch - (invoker.braced ? 0.18 : 0.42), SPF_INTERPOLATE);
        }
        MSYB A 1;
        MSYA A 2
        {
            
            
            
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

            invoker.stability -= invoker.braced ? 1 : 2;
            if (invoker.stability < 55)
                invoker.stability = 55;

            
            
            
            A_SetPitch(pitch - (invoker.braced ? 0.14 : 0.32), SPF_INTERPOLATE);
        }
        MSYB A 1;
        MSYA A 3
        {
            
            
            
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
            
            
            
            A_SetPitch(pitch - 2.0, SPF_INTERPOLATE);
            
            return ResolveState(null);
        }
        MSYA A 3;
        MSYA A 4;
        MSYA A 2;
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

    // Procedural left-hand slide; the render-only mirror flips this live offset.
    action void A_TLHDualWeaponOffset(double wx, double wy, int flags = 0)
    {
        TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
        Weapon dualWeapon = Weapon(invoker);
        if (tlhPlayer && tlhPlayer.tlhDualWieldWeapon == dualWeapon)
            wx -= 36.0 * tlhPlayer.GetTLHDualPrimarySlide();
        A_WeaponOffset(wx, wy, flags);
    }

    action void A_TLHDualOverlayOffset(int layer, double wx, double wy, int flags = 0)
    {
        if (layer == PSP_WEAPON)
        {
            TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
            Weapon dualWeapon = Weapon(invoker);
            bool dualPresentation = tlhPlayer &&
                tlhPlayer.tlhDualWieldWeapon == dualWeapon &&
                tlhPlayer.tlhDualWieldActive;

            if (dualPresentation)
                wx -= 36.0 * tlhPlayer.GetTLHDualPrimarySlide();
        }
        A_OverlayOffset(layer, wx, wy, flags);
    }

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
        TacticalPlayer dualPlayer = TacticalPlayer(Owner);
        if (dualPlayer && dualPlayer.tlhDualWieldActive &&
            dualPlayer.tlhDualWieldWeapon == self &&
            (fireMode == PrimaryFire || fireMode == AltFire))
        {
            bool infinite = sv_infiniteammo ||
                (Owner && Owner.FindInventory("PowerInfiniteAmmo", true));
            int needed = nukeMode ? 10 : 1;
            if (!requireAmmo || infinite) return true;
            return Owner && Owner.CountInv("RocketAmmo") >= needed;
        }
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
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
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
        RISG A 2 A_TLHDualWeaponOffset(0, 36, WOF_INTERPOLATE);
        RISG A 2 A_TLHDualWeaponOffset(0, 42, WOF_INTERPOLATE);
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
        RISG A 2 A_TLHDualWeaponOffset(0, 36, WOF_INTERPOLATE);
        RISG A 2 A_TLHDualWeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    Fire:
        RISG A 0
        {
            TacticalPlayer dualPlayer = TacticalPlayer(player.mo);
            if (dualPlayer && dualPlayer.tlhDualWieldActive &&
                dualPlayer.tlhDualWieldWeapon == invoker)
                return ResolveState("Ready");
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
            
            A_Quake(3, 8, 0, 200);
            A_StartSound("weapons/rocklf", CHAN_WEAPON);
        }
        RISG B 20;
        Goto Ready;


    FireDualLeft:
        RISG A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            int cost = invoker.nukeMode ? 10 : 1;
            if (!infinite && (!player.mo || player.mo.CountInv("RocketAmmo") < cost))
                return ResolveState("DualMirrorHold");
            A_TakeInventory("RocketAmmo", cost, TIF_NOTAKEINFINITE);
            if (invoker.nukeMode)
            {
                A_FireProjectile("NukeMissile", useammo: false);
                A_SetPitch(pitch - 10.0, SPF_INTERPOLATE);
                
                A_Quake(3, 8, 0, 200);
            }
            else
            {
                A_FireProjectile("Rocket", useammo: false);
                A_SetPitch(pitch - 3.0, SPF_INTERPOLATE);
            }
            A_StartSound("weapons/rocklf", CHAN_WEAPON);
            return ResolveState(null);
        }
        RISG B 12;
        RISG A 0
        {
            if (player.cmd.buttons & BT_ATTACK) return ResolveState("FireDualLeft");
            return ResolveState("DualMirrorHold");
        }

    FireDualRight:
        RISG A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            int cost = invoker.nukeMode ? 10 : 1;
            if (!infinite && (!player.mo || player.mo.CountInv("RocketAmmo") < cost))
                return ResolveState("DualMirrorHold");
            A_TakeInventory("RocketAmmo", cost, TIF_NOTAKEINFINITE);
            if (invoker.nukeMode)
            {
                A_FireProjectile("NukeMissile", useammo: false);
                A_SetPitch(pitch - 10.0, SPF_INTERPOLATE);
                
                A_Quake(3, 8, 0, 200);
            }
            else
            {
                A_FireProjectile("Rocket", useammo: false);
                A_SetPitch(pitch - 3.0, SPF_INTERPOLATE);
            }
            A_StartSound("weapons/rocklf", CHAN_WEAPON);
            return ResolveState(null);
        }
        RISG B 12;
        RISG A 0
        {
            if (player.cmd.buttons & BT_ALTATTACK) return ResolveState("FireDualRight");
            return ResolveState("DualMirrorHold");
        }

    AltFire:
        RISG B 0
        {
            TacticalPlayer dualPlayer = TacticalPlayer(player.mo);
            if (dualPlayer && dualPlayer.tlhDualWieldActive &&
                dualPlayer.tlhDualWieldWeapon == invoker)
                return ResolveState("Ready");
            return ResolveState(null);
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
        RISG B 2
        {
            A_FireProjectile("MicroMissile");
            A_SetPitch(pitch - 1.0, SPF_INTERPOLATE);
        }
        RISG B 15;
        Goto Ready;

    // Emergency melee: strike with the launcher body. It does not magically fire pistol ammo.
    Zoom:
        RISG A 3 A_TLHDualWeaponOffset(0, 36, WOF_INTERPOLATE);
        RISG B 4
        {
            A_CustomPunch(20, TRUE, 0, "BulletPuff", 48, 0, 0, "ArmorBonus", "weapons/melee");
            A_SetPitch(pitch - 1.2, SPF_INTERPOLATE);
        }
        RISG A 7 A_TLHDualWeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto Ready;

    DualMirrorHold:
        TNT1 A -1;
        Stop;

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
            A_ClearOverlays(TLH_DUAL_MIRROR_LAYER, TLH_DUAL_MIRROR_LAYER);
            A_OverlayOffset(PSP_WEAPON, 0, 32);
            A_OverlayRotate(PSP_WEAPON, 0);
            return ResolveState(null);
        }
        PLSG A 1
        {
            A_OverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
            A_WeaponReady(WRF_ALLOWZOOM | WRF_ALLOWRELOAD);
        }
        Loop;

    Deselect:
        PLSG A 0
        {
            A_ClearOverlays(TLH_DUAL_MIRROR_LAYER, TLH_DUAL_MIRROR_LAYER);
            A_OverlayRotate(PSP_WEAPON, 0);
        }
        PLSG A 1 A_Lower;
        Loop;

    Select:
        PLSG A 0
        {
            A_ClearOverlays(TLH_DUAL_MIRROR_LAYER, TLH_DUAL_MIRROR_LAYER);
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
                A_Print("PLASMA RIFLE: EMP MODE");
            }
            else
            {
                A_StartSound("weapons/sshotl", CHAN_WEAPON);
                A_Print("PLASMA RIFLE: STANDARD");
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
        // Standard plasma bolts cycle at 3 tics per shot (~700 RPM at 35 tics/sec).
        PLSG A 2
        {
            
            A_FirePlasma();
            A_SetPitch(pitch - 0.3, SPF_INTERPOLATE);
        }
        PLSG B 1 A_ReFire;
        Goto Ready;

    FireEMP:
        PLSG A 5
        {
            A_FireProjectile("EMPPlasma");
            A_SetPitch(pitch - 1.5, SPF_INTERPOLATE);
            A_Quake(1, 3, 0, 100);
        }
        PLSG B 20 A_ReFire;
        Goto Ready;

    AltFire:
        PLSG A 5;
        PLSG B 5
        {
            A_FireProjectile("GravityOrb");
            A_SetPitch(pitch - 3.0, SPF_INTERPOLATE);
        }
        PLSG B 10;
        Goto Ready;

    Zoom:
        PLSG A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && (!player.mo || player.mo.CountInv("Cell") < 7))
                return ResolveState("Ready");
            return ResolveState("PlasmaSpread");
        }
    PlasmaSpread:
        PLSG A 4 A_StartSound("weapons/sshoto", CHAN_WEAPON);
        PLSG B 4
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite)
                A_TakeInventory("Cell", 7, TIF_NOTAKEINFINITE);
            for (int i = -3; i <= 3; i++)
            {
                A_FireProjectile("PlasmaBall", i * 5, false);
            }
            A_SetPitch(pitch - 3.0, SPF_INTERPOLATE);
        }
        PLSG B 15;
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
            A_OverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
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
        ZFGG A 20 A_BFGSound;
        ZFGG B 10 A_GunFlash;
        ZFGG B 10
        {
            A_FireBFG();
            A_SetPitch(pitch - 5.0, SPF_INTERPOLATE);
            A_Quake(5, 15, 0, 500);
        }
        ZFGG B 20 A_ReFire;
        Goto Ready;

    AltFire:
        ZFGG A 0
        {
            if ((sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) || player.mo.CountInv("Cell") >= 10) return ResolveState("DoBFGBurst");
            return ResolveState("Ready");
        }
    DoBFGBurst:
        ZFGG A 10;
        ZFGG B 5
        {
            A_TakeInventory("Cell", 10, TIF_NOTAKEINFINITE);
            A_Explode(50, 128, XF_EXPLICITDAMAGETYPE, false, 128);
            
            Thrust(15, pitch - 90);
            A_SetPitch(pitch - 6.0, SPF_INTERPOLATE);
            A_Quake(4, 10, 0, 200);
        }
        ZFGG B 15;
        Goto Ready;

    Zoom:
        ZFGG A 0
        {
            if ((sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) || player.mo.CountInv("Cell") >= 10) return ResolveState("DoBFGBeam");
            return ResolveState("Ready");
        }
    DoBFGBeam:
        ZFGG A 10 A_BFGSound;
        ZFGG B 5
        {
            A_TakeInventory("Cell", 10, TIF_NOTAKEINFINITE);
            A_FireProjectile("BFGBeam", useammo: false);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
        }
        ZFGG B 15;
        Goto Ready;

    Reload:
        ZFGG A 0
        {
            if ((sv_infiniteammo || player.mo.FindInventory("PowerInfiniteAmmo", true)) || player.mo.CountInv("Cell") >= 10) return ResolveState("DoSlowOrb");
            return ResolveState("Ready");
        }
    DoSlowOrb:
        ZFGG A 30 A_BFGSound;
        ZFGG B 10 A_GunFlash;
        ZFGG B 10
        {
            A_TakeInventory("Cell", 10, TIF_NOTAKEINFINITE);
            A_FireProjectile("BFGSlowOrb", useammo: false);
            A_SetPitch(pitch - 10.0, SPF_INTERPOLATE);
            
            A_Quake(3, 10, 0, 300);
        }
        ZFGG B 30;
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

    // Procedural left-hand slide; the render-only mirror flips this live offset.
    action void A_TLHDualWeaponOffset(double wx, double wy, int flags = 0)
    {
        TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
        Weapon dualWeapon = Weapon(invoker);
        if (tlhPlayer && tlhPlayer.tlhDualWieldWeapon == dualWeapon)
            wx -= 36.0 * tlhPlayer.GetTLHDualPrimarySlide();
        A_WeaponOffset(wx, wy, flags);
    }

    action void A_TLHDualOverlayOffset(int layer, double wx, double wy, int flags = 0)
    {
        if (layer == PSP_WEAPON)
        {
            TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
            Weapon dualWeapon = Weapon(invoker);
            bool dualPresentation = tlhPlayer &&
                tlhPlayer.tlhDualWieldWeapon == dualWeapon &&
                tlhPlayer.tlhDualWieldActive;

            if (dualPresentation)
                wx -= 36.0 * tlhPlayer.GetTLHDualPrimarySlide();
        }
        A_OverlayOffset(layer, wx, wy, flags);
    }

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

    }


    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        TacticalPlayer dualPlayer = TacticalPlayer(Owner);
        if (dualPlayer && dualPlayer.tlhDualWieldActive &&
            dualPlayer.tlhDualWieldWeapon == self &&
            (fireMode == PrimaryFire || fireMode == AltFire))
        {
            bool infinite = sv_infiniteammo ||
                (Owner && Owner.FindInventory("PowerInfiniteAmmo", true));
            if (!requireAmmo || infinite) return true;
            return Owner && Owner.CountInv("Cell") >= 10;
        }
        return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, ammocount);
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
            A_TLHDualWeaponOffset(0, 32, WOF_INTERPOLATE);
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
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
        ZLSG A 0
        {
            TacticalPlayer dualPlayer = TacticalPlayer(player.mo);
            if (dualPlayer && dualPlayer.tlhDualWieldActive &&
                dualPlayer.tlhDualWieldWeapon == invoker)
                return ResolveState("Ready");
            return ResolveState(null);
        }
        ZLSG A 4;
        ZLSG B 6
        {
            A_GunFlash();
            
            A_FireProjectile("GaussSlug");
            A_StartSound("weapons/railgf", CHAN_WEAPON);
            A_SetPitch(pitch - 7.0, SPF_INTERPOLATE);
            A_Quake(7, 14, 0, 350);
            
        }
        ZLSG B 28;
        ZLSG A 8;
        Goto Ready;


    FireDualLeft:
        ZLSG A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && (!player.mo || player.mo.CountInv("Cell") < 10))
                return ResolveState("DualMirrorHold");
            A_TakeInventory("Cell", 10, TIF_NOTAKEINFINITE);
            A_FireProjectile("GaussSlug", useammo: false);
            A_StartSound("weapons/railgf", CHAN_WEAPON);
            A_SetPitch(pitch - 7.0, SPF_INTERPOLATE);
            A_Quake(7, 14, 0, 350);
            
            return ResolveState(null);
        }
        ZLSG B 28;
        ZLSG A 8;
        ZLSG A 0
        {
            if (player.cmd.buttons & BT_ATTACK) return ResolveState("FireDualLeft");
            return ResolveState("DualMirrorHold");
        }

    FireDualRight:
        ZLSG A 0
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && (!player.mo || player.mo.CountInv("Cell") < 10))
                return ResolveState("DualMirrorHold");
            A_TakeInventory("Cell", 10, TIF_NOTAKEINFINITE);
            A_FireProjectile("GaussSlug", useammo: false);
            A_StartSound("weapons/railgf", CHAN_WEAPON);
            A_SetPitch(pitch - 7.0, SPF_INTERPOLATE);
            A_Quake(7, 14, 0, 350);
            
            return ResolveState(null);
        }
        ZLSG B 28;
        ZLSG A 8;
        ZLSG A 0
        {
            if (player.cmd.buttons & BT_ALTATTACK) return ResolveState("FireDualRight");
            return ResolveState("DualMirrorHold");
        }

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
            TacticalPlayer dualPlayer = TacticalPlayer(player.mo);
            if (dualPlayer && dualPlayer.tlhDualWieldActive &&
                dualPlayer.tlhDualWieldWeapon == invoker)
                return ResolveState("Ready");
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

    DualMirrorHold:
        TNT1 A -1;
        Stop;

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

        Scale 0.56;
    }

    States
    {
    Ready:
        MISG A 0;

    TLHPickupReadyShim:
        MISG A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.72, 0.76);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, false);
        }
        MISG A 1
        {
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
            A_OverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
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
            A_OverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_OverlayRotate(PSP_WEAPON, 0);
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

// Bolt-action Hunter Rifle. Uses RIFLA0-RIFLD0 for the shot and RIFLE0-RIFLH0
// for the bolt-cycle animation. No separate Flash state is used because the
// authored A-D frames already contain the muzzle flash.
class HunterRifle : Weapon
{
    const MagazineSize = 5;
    int magazineAmmo;
    bool magazineInitialized;
    bool shotLatched;
    bool reloadLatched;
    bool aimActive;

    Default
    {
        Weapon.SlotNumber 4;
        Weapon.SlotPriority 4.45;
        Weapon.SelectionOrder 445;
        Weapon.Kickback 170;
        Weapon.AmmoType1 "Clip";
        Weapon.AmmoGive1 10;
        Weapon.AmmoUse1 0;
        Weapon.AmmoType2 "Clip";
        Weapon.AmmoUse2 0;
        Inventory.PickupMessage "Picked up the Hunter Rifle.";
    }

    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        bool infinite = sv_infiniteammo ||
            (Owner && Owner.FindInventory("PowerInfiniteAmmo", true));

        // M2 is used to enter and leave the held-aim state, even with an empty rifle.
        if (fireMode == AltFire || infinite || magazineAmmo > 0)
            return true;

        // Permit the Fire state to report an empty magazine when reserve ammo exists.
        if (Owner && Owner.CountInv("Clip") > 0)
            return true;

        return false;
    }

    States
    {
    Ready:
        PISG A 0;

    HunterRifleReadyShim:
        RIFL H 0
        {
            A_OverlayScale(PSP_WEAPON, 1.0, 1.0);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
            A_OverlayFlags(PSP_WEAPON, PSPF_PLAYERTRANSLATED, true);
        }
        RIFL H 1
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (!invoker.magazineInitialized)
            {
                invoker.magazineInitialized = true;
                if (infinite)
                {
                    invoker.magazineAmmo = MagazineSize;
                }
                else if (player.mo)
                {
                    int loaded = min(MagazineSize, player.mo.CountInv("Clip"));
                    invoker.magazineAmmo = loaded;
                    if (loaded > 0)
                        A_TakeInventory("Clip", loaded, TIF_NOTAKEINFINITE);
                }
            }

            if (!(player.cmd.buttons & BT_ATTACK))
                invoker.shotLatched = false;
            if (!(player.cmd.buttons & BT_RELOAD))
                invoker.reloadLatched = false;

            int readyFlags = 0;
            if (!invoker.reloadLatched)
                readyFlags |= WRF_ALLOWRELOAD;
            if (invoker.shotLatched)
                readyFlags |= WRF_NOPRIMARY;

            // M2 remains available as AltFire; the rifle only interprets it as aim.
            A_WeaponReady(readyFlags);
        }
        Loop;

    Select:
        RIFL H 1 A_Raise;
        Loop;

    Deselect:
        RIFL H 1
        {
            A_ZoomFactor(1.0, 1);
            invoker.aimActive = false;
            A_Lower();
        }
        Loop;

    Fire:
        RIFL A 0
        {
            invoker.shotLatched = true;
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && invoker.magazineAmmo <= 0)
                return ResolveState("DryFire");
            return ResolveState(null);
        }
        RIFL A 1;
        RIFL B 1
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite)
                invoker.magazineAmmo--;

            // One accurate hitscan round; all firing visuals are in RIFLA0-D0.
            A_FireBullets(0.04, 0.02, 1, 36, "BulletPuff", 0);
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            
            
        }
        RIFL C 1;
        RIFL D 1;
        Goto BoltCycle;

    // Hold M2 to keep the FOV zoomed. Primary fire is handled here manually
    // so holding the aim button does not block the trigger button.
    AltFire:
        RIFL H 0
        {
            invoker.aimActive = true;
            A_ZoomFactor(2.25, 1);
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            return ResolveState("AimLoop");
        }

    AimLoop:
        RIFL H 1
        {
            if (!(player.cmd.buttons & BT_ALTATTACK))
            {
                A_ZoomFactor(1.0, 1);
                invoker.aimActive = false;
                if (!(player.cmd.buttons & BT_ATTACK))
                    invoker.shotLatched = false;
                return ResolveState("Ready");
            }

            A_ZoomFactor(2.25);
            if (!(player.cmd.buttons & BT_ATTACK))
                invoker.shotLatched = false;

            if ((player.cmd.buttons & BT_ATTACK) && !invoker.shotLatched)
            {
                invoker.shotLatched = true;
                bool infinite = sv_infiniteammo ||
                    (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
                if (!infinite && invoker.magazineAmmo <= 0)
                    return ResolveState("DryFire");
                return ResolveState("Fire");
            }

            if (!(player.cmd.buttons & BT_RELOAD))
                invoker.reloadLatched = false;

            int readyFlags = WRF_NOFIRE;
            if (!invoker.reloadLatched)
                readyFlags |= WRF_ALLOWRELOAD;
            A_WeaponReady(readyFlags);
            // This inline state function has early-return paths above, so its
            // normal path must explicitly resolve the current state as well.
            return ResolveState(null);
        }
        Loop;

    DryFire:
        RIFL H 3
        {
            A_StartSound("weapons/sshoto", CHAN_WEAPON);
            A_Print("HUNTER RIFLE: EMPTY | PRESS R");
            if (player.cmd.buttons & BT_ALTATTACK)
            {
                invoker.aimActive = true;
                A_ZoomFactor(2.25, 1);
                return ResolveState("AimLoop");
            }
            A_ZoomFactor(1.0, 1);
            invoker.aimActive = false;
            return ResolveState("Ready");
        }

    BoltCycle:
        // RIFLE0 -> RIFLH0: pull, extract/eject, push the next cartridge, lock.
        RIFL E 3;
        RIFL F 3;
        RIFL G 3;
        RIFL H 3
        {
            A_StartSound("weapons/sshotl", CHAN_WEAPON);
            if (!(player.cmd.buttons & BT_ATTACK))
                invoker.shotLatched = false;


            if (player.cmd.buttons & BT_ALTATTACK)
            {
                invoker.aimActive = true;
                A_ZoomFactor(2.25, 1);
                return ResolveState("AimLoop");
            }

            A_ZoomFactor(1.0, 1);
            invoker.aimActive = false;
            return ResolveState("Ready");
        }

    Reload:
        RIFL H 0
        {
            invoker.reloadLatched = true;
            A_ZoomFactor(1.0, 1);
            invoker.aimActive = false;

            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (!infinite && invoker.magazineAmmo >= MagazineSize)
            {
                A_Print("HUNTER RIFLE: MAGAZINE FULL");
                if (player.cmd.buttons & BT_ALTATTACK)
                {
                    invoker.aimActive = true;
                    A_ZoomFactor(2.25, 1);
                    return ResolveState("AimLoop");
                }
                return ResolveState("Ready");
            }

            if (!infinite && (!player.mo || player.mo.CountInv("Clip") <= 0))
            {
                A_StartSound("weapons/sshoto", CHAN_WEAPON);
                A_Print("HUNTER RIFLE: NO RESERVE AMMO");
                if (player.cmd.buttons & BT_ALTATTACK)
                {
                    invoker.aimActive = true;
                    A_ZoomFactor(2.25, 1);
                    return ResolveState("AimLoop");
                }
                return ResolveState("Ready");
            }

            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            return ResolveState(null);
        }
        RIFL E 4;
        RIFL F 4;
        RIFL G 4;
        RIFL H 4
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (infinite)
            {
                invoker.magazineAmmo = MagazineSize;
            }
            else if (player.mo)
            {
                int reserve = player.mo.CountInv("Clip");
                int needed = MagazineSize - invoker.magazineAmmo;
                int loaded = min(needed, reserve);
                if (loaded > 0)
                {
                    A_TakeInventory("Clip", loaded, TIF_NOTAKEINFINITE);
                    invoker.magazineAmmo += loaded;
                }
            }

            A_StartSound("weapons/sshotl", CHAN_WEAPON);

            if (player.cmd.buttons & BT_ALTATTACK)
            {
                invoker.aimActive = true;
                A_ZoomFactor(2.25, 1);
                return ResolveState("AimLoop");
            }
            return ResolveState("Ready");
        }

    Spawn:
        // Dedicated world pickup sprite: RFLEA0.
        RFLE A -1;
        Stop;
    }
}

// Custom Service Revolver.
// GZDoom requires a four-character sprite prefix. All frames use RVOL:
// RVOLQ0 (idle), RVOLA0/RVOLB0/RVOLC0 (fire frames), RVOLG0 (world pickup).
class ServiceRevolver : Weapon
{
    // State-action wrappers calculate the slide directly from the owning
    // player. Do not call a normal Weapon member helper from an action method:
    // GZDoom gives those calls different self contexts during state execution.
    action void A_TLHDualWeaponOffset(double wx, double wy, int flags = 0)
    {
        // In a weapon action, self is the player pawn and invoker is this weapon.
        TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
        Weapon dualWeapon = Weapon(invoker);
        if (tlhPlayer && tlhPlayer.tlhDualWieldWeapon == dualWeapon)
        {
            double slide = tlhPlayer.GetTLHDualPrimarySlide();
            wx -= 36.0 * slide;
        }
        A_WeaponOffset(wx, wy, flags);
    }

    action void A_TLHDualOverlayOffset(int layer, double wx, double wy, int flags = 0)
    {
        if (layer == PSP_WEAPON)
        {
            TacticalPlayer tlhPlayer = TacticalPlayer(player.mo);
            Weapon dualWeapon = Weapon(invoker);
            bool dualPresentation = tlhPlayer &&
                tlhPlayer.tlhDualWieldWeapon == dualWeapon &&
                tlhPlayer.tlhDualWieldActive;

            if (dualPresentation)
                wx -= 36.0 * tlhPlayer.GetTLHDualPrimarySlide();
        }
        A_OverlayOffset(layer, wx, wy, flags);
    }



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
            return ResolveState(null);
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

            int readyFlags = 0;
            if (!invoker.reloadLatched)
                readyFlags |= WRF_ALLOWRELOAD;
            if (invoker.triggerLatched || invoker.altTriggerLatched)
                readyFlags |= WRF_NOPRIMARY | WRF_NOSECONDARY;

            // Keep GZDoom's native weapon bob enabled.
            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32, 0);
            A_WeaponReady(readyFlags);
        }
        Loop;

    DualMirrorHold:
        TNT1 A -1;
        Stop;

    Deselect:
        RVOL Q 0
        {
        }
        RVOL Q 1 A_Lower;
        Loop;

    Select:
        RVOL Q 0
        {
        }
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
        {            A_TLHDualOverlayOffset(PSP_WEAPON, 2, 39, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -4.0);
        }
        RVOL Q 8
        {            A_TLHDualOverlayOffset(PSP_WEAPON, 4, 43, WOF_INTERPOLATE);
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
        {            A_TLHDualOverlayOffset(PSP_WEAPON, 1, 36, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, -3.0);
        }
        RVOL Q 5
        {            A_TLHDualOverlayOffset(PSP_WEAPON, 0, 32, WOF_INTERPOLATE);
            A_OverlayRotate(PSP_WEAPON, 0);
            
        }
        Goto Ready;

    // Single-action trigger: high per-shot impact, narrow spread, deliberate recovery.
    Fire:
        RVOL A 0
        {
            let tp = TacticalPlayer(player.mo);
            if (tp && tp.tlhDualWieldActive && tp.tlhDualWieldWeapon == invoker)
                return ResolveState("Ready");

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
            
            

            if (!infinite && invoker.cylinderAmmo == 1)
                A_Print("REVOLVER: LAST ROUND");
            else if (!infinite && invoker.cylinderAmmo == 0)
                A_Print("REVOLVER: CYLINDER EMPTY | PRESS R");
        }
        RVOL C 2
        {            
            
        }
        RVOL Q 4
        {            
            
        }
        Goto Ready;

    FireDualLeft:
        RVOL Q 0
        {
            invoker.triggerLatched = true;
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && invoker.cylinderAmmo <= 0)
            {
                A_StartSound("weapons/sshoto", CHAN_WEAPON);
                A_Print("REVOLVER: CYLINDER EMPTY | PRESS R");
                return ResolveState("DualMirrorHold");
            }

            if (!infinite)
                invoker.cylinderAmmo--;

            A_FireBullets(0.18, 0.12, 1, 8, "BulletPuff", 0);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 3.2, SPF_INTERPOLATE);
            
            
            

            if (!infinite && invoker.cylinderAmmo == 1)
                A_Print("REVOLVER: LAST ROUND");
            else if (!infinite && invoker.cylinderAmmo == 0)
                A_Print("REVOLVER: CYLINDER EMPTY | PRESS R");
            return ResolveState(null);
        }
        RVOL B 2;
        RVOL Q 0
        {
            if ((player.cmd.buttons & BT_ATTACK) && !invoker.triggerLatched)
                return ResolveState("FireDualLeft");
            return ResolveState("DualMirrorHold");
        }

    FireDualRight:
        RVOL Q 0
        {
            invoker.altTriggerLatched = true;
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && invoker.cylinderAmmo <= 0)
            {
                A_StartSound("weapons/sshoto", CHAN_WEAPON);
                A_Print("REVOLVER: CYLINDER EMPTY | PRESS R");
                return ResolveState("DualMirrorHold");
            }

            if (!infinite)
                invoker.cylinderAmmo--;

            A_FireBullets(0.18, 0.12, 1, 8, "BulletPuff", 0);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 3.2, SPF_INTERPOLATE);
            
            
            

            if (!infinite && invoker.cylinderAmmo == 1)
                A_Print("REVOLVER: LAST ROUND");
            else if (!infinite && invoker.cylinderAmmo == 0)
                A_Print("REVOLVER: CYLINDER EMPTY | PRESS R");
            return ResolveState(null);
        }
        RVOL B 2;
        RVOL Q 0
        {
            if ((player.cmd.buttons & BT_ALTATTACK) && !invoker.altTriggerLatched)
                return ResolveState("FireDualRight");
            return ResolveState("DualMirrorHold");
        }

    // Fan the Hammer: three fast, progressively less accurate shots. It uses
    // three loaded rounds, is triggered once per click, and cannot be spammed by holding M2.
    AltFire:
        RVOL Q 0
        {
            let tp = TacticalPlayer(player.mo);
            if (tp && tp.tlhDualWieldActive && tp.tlhDualWieldWeapon == invoker)
                return ResolveState("Ready");

            invoker.altTriggerLatched = true;
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));

            if (!infinite && invoker.cylinderAmmo < 3)
            {
                A_StartSound("weapons/sshoto", CHAN_WEAPON);
                A_Print("REVOLVER: FAN NEEDS 3 ROUNDS | PRESS R");
                return ResolveState("Ready");
            }
            return ResolveState("FanFire1");
        }
    FanFire1:
        // M4A1-style burst rhythm: show the pre-shot A frame for one tic,
        // then the B firing frame; repeat for each cartridge.
        RVOL A 1
        {            
            
        }
        RVOL B 1
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && invoker.cylinderAmmo > 0) invoker.cylinderAmmo--;
            A_FireBullets(0.7, 0.3, 1, 4, "BulletPuff", 0);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 0.8, SPF_INTERPOLATE);
            
            
        }
        RVOL A 1
        {            
            
        }
        RVOL B 1
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && invoker.cylinderAmmo > 0) invoker.cylinderAmmo--;
            A_FireBullets(1.8, 0.7, 1, 4, "BulletPuff", 0);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 1.0, SPF_INTERPOLATE);
            
            
        }
        RVOL A 1
        {            
            
        }
        RVOL B 1
        {
            bool infinite = sv_infiniteammo ||
                (player.mo && player.mo.FindInventory("PowerInfiniteAmmo", true));
            if (!infinite && invoker.cylinderAmmo > 0) invoker.cylinderAmmo--;
            A_FireBullets(3.0, 1.0, 1, 4, "BulletPuff", 0);
            A_StartSound("weapons/pistol", CHAN_WEAPON);
            A_SetPitch(pitch - 1.4, SPF_INTERPOLATE);
            
            
            if (!infinite && invoker.cylinderAmmo <= 0)
                A_Print("REVOLVER: CYLINDER EMPTY | PRESS R");
        }
        RVOL C 3
        {            
            
        }
        RVOL Q 4
        {            
            
        }
        Goto Ready;

    Spawn:
        RVOL G -1;
        Stop;
    }
}



class SimpleRifle : Weapon
{
    bool Aiming;
    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        TacticalPlayer tp = TacticalPlayer(Owner);
        if (tp && tp.tlhBlueSimpleRifleUnlocked)
        {
            if (sv_infiniteammo || Owner.FindInventory("PowerInfiniteAmmo"))
                return true;
            Inventory cells = Owner.FindInventory("Cell");
            int cellCost = (fireMode == AltFire) ? 2 : 1;
            return cells && cells.Amount >= cellCost;
        }
        return Super.CheckAmmo(fireMode, autoSwitch, requireAmmo, ammocount);
    }
Default
    {
        Weapon.SlotNumber 2;
        Weapon.SlotPriority 3.25;
        Weapon.SelectionOrder 325;
        Weapon.Kickback 125;
        Weapon.AmmoType1 "Clip";
        Weapon.AmmoGive1 16;
        Weapon.AmmoUse1 1;
        Weapon.AmmoType2 "Clip";
		Weapon.AmmoGive2 16;
        Weapon.AmmoUse2 2;
        Inventory.PickupMessage "Picked up a Simple Rifle.";
    }

    States (actor)
    {
    Spawn:
        ASRQ A -1;
        Stop;
    }

    States (weapon)
    {
    Ready:
        PISG A 0;

    TLHPickupReadyShim:
        ASLT A 0
        {
            A_OverlayScale(PSP_WEAPON, 0.96, 1.02);
            A_OverlayPivotAlign(PSP_WEAPON, PSPA_CENTER, PSPA_BOTTOM);
        }
        ASLT A 1 A_WeaponReady(WRF_ALLOWRELOAD);
        Loop;

    Deselect:
        ASLT A 1 A_Lower;
        Loop;

    Select:
        ASLT A 1
        {
            A_OverlayScale(PSP_WEAPON, 0.96, 1.02);
            A_Raise();
        }
        Loop;

    Fire:
        ASLT A 0
        {
            TacticalPlayer tp = TacticalPlayer(invoker.Owner);
            if (tp && tp.tlhBlueSimpleRifleUnlocked)
                return ResolveState("BlueFire");
            return ResolveState(null);
        }
        ASLT A 5 A_GunFlash;
        ASLT B 5
        {
            A_FireBullets(7.0, 5.5, 8, 4, "BulletPuff");
            A_StartSound("weapons/shotgf", CHAN_WEAPON);
            A_SetPitch(pitch - 2.3, SPF_INTERPOLATE);
            
        }
        ASLT A 7 A_ReFire;
        Goto Ready;

    BlueFire:
        ASLT A 2 A_GunFlash;
        ASLT B 4
        {
            Actor rifleOwner = invoker.Owner;
            if (rifleOwner)
                rifleOwner.TakeInventory("Cell", 1, true, true);
            A_RailAttack(42, 0, false, 0x36BFFF, 0xD9F7FF,
                RGF_FULLBRIGHT, 0, "BulletPuff", 0, 0, 8192, 9, 1.0, 1.0);
            A_StartSound("weapons/railgf", CHAN_WEAPON);
            A_SetPitch(pitch - 1.8, SPF_INTERPOLATE);
            
        }
        ASLT A 6 A_ReFire;
        Goto Ready;

    AltFire:
        ASLT A 0
        {
            TacticalPlayer tp = TacticalPlayer(invoker.Owner);
            if (tp && tp.tlhBlueSimpleRifleUnlocked)
                return ResolveState("BlueAltFire");
            return ResolveState(null);
        }
        SHTG B 2
        {
            A_FireBullets(4.5, 3.5, 14, 4, "BulletPuff");
            A_StartSound("weapons/sshotf", CHAN_WEAPON);
            A_SetPitch(pitch - 4.0, SPF_INTERPOLATE);
            
        }
        SHTG C 4;
        ASLT B 5;
        ASLT A 5;
        Goto Ready;

    BlueAltFire:
        ASLT A 3 A_GunFlash;
        ASLT B 6
        {
            Actor rifleOwner = invoker.Owner;
            if (rifleOwner)
                rifleOwner.TakeInventory("Cell", 2, true, true);
            A_RailAttack(78, 0, false, 0x238DFF, 0xE4FAFF,
                RGF_FULLBRIGHT, 0, "BulletPuff", 0.35, 0.15, 8192, 12, 0.75, 1.0);
            A_StartSound("weapons/railgf", CHAN_WEAPON);
            A_SetPitch(pitch - 3.0, SPF_INTERPOLATE);
            
        }
        ASLT A 8 A_ReFire;
        Goto Ready;
		
	Reload:
		ASLT A 3 A_GunFlash;
		ASLT A 9
		{
			A_Print("3/3");
			A_FireProjectile("FlakGrenade");
			A_GunFlash;
		}
		ASLT A 9
		{
			A_Print("2/3");
			A_FireProjectile("FlakGrenade");
			A_GunFlash;
		}
		ASLT A 9
		{
			A_Print("1/3");
			A_FireProjectile("FlakGrenade");
			A_GunFlash;
		}
		ASLT B 3 A_Print("0/3");
		SHTG B 4;
		ASLT B 5;
		Goto Ready;
		
	Zoom:
		ASLT A 1
			{
				if(!invoker.Aiming)
				{
					A_ZoomFactor(3.0);
					invoker.Aiming = True;
				}
				else
				{
					A_ZoomFactor(1.0);
					invoker.Aiming = False;
				}
			}
		ASLT A 5;
		Goto Ready;

    Flash:
        ASLF A 3 Bright A_Light1;
        ASLF B 3 Bright A_Light2;
        Goto LightDone;

    }
}


class TacticalPlayer : DoomPlayer replaces DoomPlayer
{
    int jumpCount;
    int slideCooldown;
    int tlhCoyoteTics;
    int tlhJumpBufferTics;
    int tlhSlideTics;
    int tlhDashTics;
    int tlhDashCooldown;
    int tlhSprintRecoveryTics;
    double tlhSprintStamina;
    bool tlhMovementInitialized;
    bool tlhIsSprinting;
    bool tlhIsSliding;
    int fallTicks;
    int akimboCooldown;
    double maximumFallSpeed;
    bool isSlamming;
    bool wasOnGround;
    bool akimboButtonHeld;

    // Blue Simple Rifle progression is owned by the player and scoped to one map.
    int tlhBlueSimpleRifleKills;
    bool tlhBlueSimpleRifleUnlocked;
    String tlhBlueSimpleRifleMap;

    // Weapons removed by a game-mode transition are destroyed after the
    // player PSprite has stopped using their states.
    Array<Weapon> tlhDeferredWeaponRemovals;

    // Player-corpse smell reaction, owned by the active player pawn.
    Actor tlhCorpseReactionTarget;
    int tlhCorpseReactionStayTics;
    int tlhCorpseReactionSoundTics;
    bool tlhCorpseReactionPlayed;
    int tlhCorpseScanCooldown;

    // Centralized dual-wield state. TacticalHUDHandler resolves the player's
    // configured +user3 binding and sends a per-player NetworkCommand here.
    bool tlhDualWieldActive;
    Weapon tlhDualWieldWeapon;
    double tlhDualOriginalPrimaryAlpha;
    bool tlhDualPrimaryAlphaCaptured;
    SpriteID tlhDualOriginalSprite;
    int tlhDualOriginalFrame;
    bool tlhDualOriginalSpriteCaptured;
    double tlhDualCloneBaseX;
    double tlhDualCloneBaseY;
    bool tlhDualCloneBaseCaptured;
    bool tlhProneActive;
    bool tlhPronePreviousShadow;
    bool tlhProneStealthActive;
    bool tlhPronePreviousMinVisible;
    double tlhPronePreviousAlpha;

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

    double tlhAnimLandingKick;
    double tlhAnimLandingVel;
    double tlhAnimDamageKick;
    double tlhAnimDamageVel;

    double tlhAnimPrevVelX;
    double tlhAnimPrevVelY;
    int tlhAnimLastAmmoSignature;
    int tlhAnimLastHealth;
    Weapon tlhAnimLastWeapon;

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
        Player.WeaponSlot 2, "RecoilPistol", "ServiceRevolver", "OfficerVulkanPistol", "SimpleRifle";
        Player.WeaponSlot 3, "RecoilShotgun", "FastRecoilSSG", "SemiAutoShotgun";
        // Slot 4 includes the M4A1, bolt-action Hunter Rifle, heavy chaingun, compact SMG and M60.
        Player.WeaponSlot 4, "TacticalM4A1", "HunterRifle", "HeavyChaingun", "TLHCompactSMG", "M60MachineGun";
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
			GiveInventory("SimpleRifle", 1, true);

            // Slot 3
            GiveInventory("RecoilShotgun", 1, true);
            GiveInventory("FastRecoilSSG", 1, true);
            GiveInventory("SemiAutoShotgun", 1, true);

            // Slot 4
            GiveInventory("TacticalM4A1", 1, true);
            GiveInventory("HunterRifle", 1, true);
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

    // Dual Wield compatibility is a gameplay contract, not a list of
    // hand-animation labels. A compatible weapon supplies two firing routes,
    // a native input entry point and one inert state used as a PSprite holder.
    bool SupportsTLHProceduralDualWield(Weapon weapon)
    {
        return weapon &&
               weapon.FindStateByString("DualMirrorHold") &&
               weapon.FindStateByString("FireDualLeft") &&
               weapon.FindStateByString("FireDualRight");
    }

    void ClearTLHDualOverlay()
    {
        if (!player)
            return;

        PSprite primary = player.FindPSprite(PSP_WEAPON);
        if (primary && tlhDualWieldWeapon && primary.Caller == tlhDualWieldWeapon)
        {
            if (tlhDualOriginalSpriteCaptured)
            {
                primary.Sprite = tlhDualOriginalSprite;
                primary.Frame = tlhDualOriginalFrame;
            }
            if (tlhDualPrimaryAlphaCaptured)
                primary.alpha = tlhDualOriginalPrimaryAlpha;
            if (tlhDualCloneBaseCaptured)
            {
                primary.x = tlhDualCloneBaseX;
                primary.y = tlhDualCloneBaseY;
            }
        }

        tlhDualOriginalPrimaryAlpha = 1.0;
        tlhDualPrimaryAlphaCaptured = false;
        tlhDualOriginalSprite = GetSpriteIndex("TNT1");
        tlhDualOriginalFrame = 0;
        tlhDualOriginalSpriteCaptured = false;
        tlhDualCloneBaseX = 0.0;
        tlhDualCloneBaseY = 32.0;
        tlhDualCloneBaseCaptured = false;

        PSprite leftClone = player.FindPSprite(TLH_DUAL_MIRROR_LAYER);
        if (leftClone) leftClone.Destroy();

        PSprite rightClone = player.FindPSprite(TLH_DUAL_SECOND_LAYER);
        if (rightClone) rightClone.Destroy();
    }

    void ResetTLHDualForWeaponSwitch()
    {
        if (!player || !tlhDualWieldActive)
            return;

        Weapon selected = player.ReadyWeapon;
        bool weaponSwitchQueued = (player.PendingWeapon != WP_NOCHANGE);
        bool ownerChanged = (tlhDualWieldWeapon != selected);
        bool selectedWeaponUnsupported =
            selected && !SupportsTLHProceduralDualWield(selected);

        // Release both clones before GZDoom completes its normal PendingWeapon
        // switch. PendingWeapon itself is never rewritten here.
        if (weaponSwitchQueued || ownerChanged || selectedWeaponUnsupported)
        {
            tlhDualWieldActive = false;
            ClearTLHDualOverlay();
            tlhDualWieldWeapon = null;
        }
    }

    // +user3 is intercepted on key-down and sent once per press. Turning the
    // mode OFF must work even while a newly picked-up weapon is pending selection.
    bool ToggleTLHDualWield(Weapon weapon)
    {
        if (!player || player.playerstate != PST_LIVE)
            return false;

        // Deactivation has priority over weapon compatibility and PendingWeapon.
        // Picking up a weapon can queue a switch without immediately changing ReadyWeapon.
        if (tlhDualWieldActive)
        {
            tlhDualWieldActive = false;
            ClearTLHDualOverlay();
            tlhDualWieldWeapon = null;
            return true;
        }

        // Only activation requires a supported, currently equipped, idle weapon.
        if (player.PendingWeapon != WP_NOCHANGE ||
            weapon == null || weapon != player.ReadyWeapon ||
            !SupportsTLHProceduralDualWield(weapon))
            return false;

        let officer = OfficerVulkanPistol(weapon);
        if (officer && officer.weaponMode != 0)
            return false;

        tlhDualWieldWeapon = weapon;
        tlhDualWieldActive = true;
        return true;
    }

    // Legacy state wrappers remain, but no longer move the engine-owned PSprite.
    double GetTLHDualPrimarySlide()
    {
        return 0.0;
    }

    // The left clone mirrors the live primary firing frame. The right clone can
    // execute FireDualRight on its own PSprite layer when M2 is pressed.
    // The hidden primary remains the M1 gameplay/action controller.
    void CopyTLHDualClone(PSprite clone, State cloneState, PSprite primary,
        bool mirrored, double cloneX, double cloneY, double cloneAlpha,
        SpriteID sourceSprite, int sourceFrame, bool preserveActiveState)
    {
        if (!clone || !cloneState || !primary)
            return;

        bool keepWeaponAnimation = preserveActiveState && clone.CurState != cloneState;
        if (!keepWeaponAnimation)
        {
            if (clone.CurState != cloneState)
                clone.SetState(cloneState);

            clone.Sprite = sourceSprite;
            clone.Frame = sourceFrame;
            clone.Tics = -1;
        }

        // The right-hand PSprite is allowed to execute FireDualRight on its
        // own overlay layer. Do not overwrite its live state/frame each tick.
        clone.Translation = primary.Translation;
        clone.scale = primary.scale;
        clone.baseScale = primary.baseScale;
        clone.pivot = primary.pivot;
        clone.rotation = mirrored ? -primary.rotation : primary.rotation;
        clone.alpha = cloneAlpha;
        clone.HAlign = primary.HAlign;
        clone.VAlign = primary.VAlign;
        clone.bPlayerTranslated = primary.bPlayerTranslated;
        clone.bPivotPercent = primary.bPivotPercent;
        clone.bInterpolate = primary.bInterpolate;
        clone.bFlip = mirrored ? !primary.bFlip : primary.bFlip;
        // bMirror also reverses position offsets. Keep it disabled so left/right placement
        // remains controlled only by the signed X coordinates calculated below.
        clone.bMirror = false;
        clone.bAddBob = false;
        clone.bAddWeapon = false;
        clone.bCVarFast = primary.bCVarFast;
        clone.bPowDouble = primary.bPowDouble;
        // Position is already expressed in screen-space overlay offsets. Do not mirror X here.
        // The mirrored appearance is handled only by bFlip below.
        clone.x = cloneX;
        clone.y = cloneY;
        clone.InterpolateTic = primary.InterpolateTic;
    }

    void UpdateTLHDualWieldPresentation(PSprite primary)
    {
        if (!player || !player.ReadyWeapon || !primary)
            return;

        Weapon weapon = player.ReadyWeapon;
        if (!tlhDualWieldActive || tlhDualWieldWeapon != weapon)
        {
            if (tlhDualWieldWeapon == weapon)
            {
                ClearTLHDualOverlay();
                tlhDualWieldWeapon = null;
            }
            return;
        }

        State cloneState = weapon.FindStateByString("DualMirrorHold");
        if (!cloneState)
            return;

        // Keep the weapon's real sprite. Dual Wield uses a procedural
        // deselect/lower motion on the active PSprite instead of a flash sprite.
        if (!tlhDualPrimaryAlphaCaptured)
        {
            tlhDualOriginalPrimaryAlpha = primary.alpha;
            tlhDualPrimaryAlphaCaptured = true;
        }
        if (!tlhDualOriginalSpriteCaptured)
        {
            tlhDualOriginalSprite = primary.Sprite;
            tlhDualOriginalFrame = primary.Frame;
            tlhDualOriginalSpriteCaptured = true;
        }

        PSprite leftClone = player.FindPSprite(TLH_DUAL_MIRROR_LAYER);
        if (!leftClone || leftClone.Caller != weapon)
        {
            if (leftClone) leftClone.Destroy();
            player.SetPsprite(TLH_DUAL_MIRROR_LAYER, cloneState);
            leftClone = player.FindPSprite(TLH_DUAL_MIRROR_LAYER);
        }

        PSprite rightClone = player.FindPSprite(TLH_DUAL_SECOND_LAYER);
        if (!rightClone || rightClone.Caller != weapon)
        {
            if (rightClone) rightClone.Destroy();
            player.SetPsprite(TLH_DUAL_SECOND_LAYER, cloneState);
            rightClone = player.FindPSprite(TLH_DUAL_SECOND_LAYER);
        }

        if (!leftClone || !rightClone)
            return;

        // Capture the weapon's authored resting coordinates exactly once.
        if (!tlhDualCloneBaseCaptured)
        {
            tlhDualCloneBaseX = primary.x;
            tlhDualCloneBaseY = primary.y;
            tlhDualCloneBaseCaptured = true;
        }

        // M1 continues through the hidden primary weapon PSprite. M2 starts
        // FireDualRight on the independent right-hand PSprite, so both hands
        // can execute their own weapon state sequences simultaneously.
        int dualButtons = player.cmd.buttons;
        int oldDualButtons = player.oldbuttons;
        bool primaryPressed = (dualButtons & BT_ATTACK) != 0 &&
                               (oldDualButtons & BT_ATTACK) == 0;
        bool altPressed = (dualButtons & BT_ALTATTACK) != 0 &&
                          (oldDualButtons & BT_ALTATTACK) == 0;

        if (primaryPressed && leftClone.CurState == cloneState)
        {
            State leftFireState = weapon.FindStateByString("FireDualLeft");
            if (leftFireState)
                leftClone.SetState(leftFireState);
        }
        if (altPressed && rightClone.CurState == cloneState)
        {
            State rightFireState = weapon.FindStateByString("FireDualRight");
            if (rightFireState)
                rightClone.SetState(rightFireState);
        }

        // A revolver uses a one-press latch on M2. Release it independently
        // of the primary-hand trigger so the next right-click can fire.
        ServiceRevolver dualRevolver = ServiceRevolver(weapon);
        if (dualRevolver)
        {
            if (!(dualButtons & BT_ATTACK))
                dualRevolver.triggerLatched = false;
            if (!(dualButtons & BT_ALTATTACK))
                dualRevolver.altTriggerLatched = false;
        }

        // Toggle state is persistent, so the two hands are placed immediately.
        // There is no timed rise/fall blend or automatic expiration.
        double cloneY = tlhDualCloneBaseY;
        double rightCloneX = tlhDualCloneBaseX + TLH_DUAL_HAND_SPREAD;
        double leftCloneX = tlhDualCloneBaseX - TLH_DUAL_HAND_SPREAD;
        double cloneAlpha = tlhDualOriginalPrimaryAlpha;

        // Mirror the live primary animation on the left clone. When the hidden
        // ZISF placeholder is encountered, fall back to the captured idle frame.
        SpriteID leftSprite = primary.Sprite;
        int leftFrame = primary.Frame;
        if (leftSprite == GetSpriteIndex("ZISF"))
        {
            leftSprite = tlhDualOriginalSprite;
            leftFrame = tlhDualOriginalFrame;
        }

        CopyTLHDualClone(leftClone, cloneState, primary,
            false, leftCloneX, cloneY, cloneAlpha, leftSprite, leftFrame, true);
        CopyTLHDualClone(rightClone, cloneState, primary,
            true, rightCloneX, cloneY, cloneAlpha,
            tlhDualOriginalSprite, tlhDualOriginalFrame, true);

        // Keep the primary state machine alive for M1, but hide its weapon body.
        primary.Sprite = GetSpriteIndex("ZISF");
        primary.Frame = 0;
        primary.x = tlhDualCloneBaseX;
        primary.y = tlhDualCloneBaseY;
        primary.alpha = tlhDualOriginalPrimaryAlpha;

        // Neither hand uses the centered engine flash overlay. Their authored
        // firing frames are rendered directly on the corresponding weapon clone.
        player.SetPsprite(PSP_FLASH, null);
    }

    override void Tick()
    {
        Super.Tick();
        if (!player || !player.mo) return;

        // The Blue Simple Rifle is a map-local mastery reward. Death does not reset it.
        if (tlhBlueSimpleRifleMap != level.MapName)
        {
            tlhBlueSimpleRifleMap = level.MapName;
            tlhBlueSimpleRifleKills = 0;
            tlhBlueSimpleRifleUnlocked = false;
        }

        // Dash/prone remain player-level script buttons. Dual Wield is toggled
        // by TacticalHUDHandler.InputProcess/NetworkCommandProcess, not weapon states.
        int bt = player.cmd.buttons;
        int obt = player.oldbuttons;
        bool tlhDashPressedThisTic = (bt & BT_USER2) != 0 && (obt & BT_USER2) == 0;

        CleanupDeferredWeaponRemovals();

        if (!tlhMovementInitialized)
        {
            tlhMovementInitialized = true;
            tlhSprintStamina = 100.0;
            tlhCoyoteTics = 0;
            tlhJumpBufferTics = 0;
            tlhSlideTics = 0;
            tlhDashTics = 0;
            tlhDashCooldown = 0;
            tlhSprintRecoveryTics = 0;
            tlhIsSprinting = false;
            tlhIsSliding = false;
            wasOnGround = (Pos.Z <= floorz + 0.5);
        }

        if (player.playerstate == PST_DEAD)
        {
            tlhDualWieldActive = false;
            ClearTLHDualOverlay();
            tlhDualWieldWeapon = null;

            if (tlhProneActive)
            {
                bShadow = tlhPronePreviousShadow;
                Height = FullHeight;
                tlhProneActive = false;
            }
            if (tlhProneStealthActive)
            {
                Alpha = tlhPronePreviousAlpha;
                bMinVisible = tlhPronePreviousMinVisible;
                tlhProneStealthActive = false;
            }

            tlhDualWieldWeapon = null;
            tlhDualWieldActive = false;
            tlhIsSprinting = false;
            tlhIsSliding = false;
            tlhSlideTics = 0;
            tlhDashTics = 0;
            tlhCoyoteTics = 0;
            tlhJumpBufferTics = 0;
            tlhSprintStamina = 100.0;
            tlhMovementInitialized = false;
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
        double forwardInput = 0.0;
        double sideInput = 0.0;
        if (bt & BT_FORWARD) forwardInput += 1.0;
        if (bt & BT_BACK) forwardInput -= 1.0;
        if (bt & BT_MOVERIGHT) sideInput += 1.0;
        if (bt & BT_MOVELEFT) sideInput -= 1.0;
        // Normalize diagonal input so sprint and air steering never gain
        // free speed from holding two directions at once.
        double inputLength = sqrt(forwardInput * forwardInput + sideInput * sideInput);
        if (inputLength > 1.0)
        {
            forwardInput /= inputLength;
            sideInput /= inputLength;
        }
        bool hasMoveInput = (abs(forwardInput) + abs(sideInput)) > 0.0;
        bool jumpPressed = (bt & BT_JUMP) != 0 && (obt & BT_JUMP) == 0;
        // Ground Slam has its own configurable +user4 bind. Crouch never
        // starts a slam while airborne, so Ctrl remains dedicated to duck/slide.
        bool groundSlamPressed = (bt & BT_USER4) != 0 &&
                                 (obt & BT_USER4) == 0;

        if (onGround)
            tlhCoyoteTics = 5;
        else if (tlhCoyoteTics > 0)
            tlhCoyoteTics--;

        if (tlhSlideTics > 0) tlhSlideTics--;
        if (tlhDashTics > 0) tlhDashTics--;
        if (tlhDashCooldown > 0) tlhDashCooldown--;
        if (slideCooldown > 0) slideCooldown--;

        // M3 (+user1) only puts the player prone when the Hunter Rifle is equipped.
        // The stance lowers the hitbox and view, dampens movement, and enables
        // monster-facing stealth while the button is held.
        Weapon proneWeapon = player.ReadyWeapon;
        bool hunterRifleEquipped = proneWeapon && proneWeapon is "HunterRifle";
        bool proneRequested = (hunterRifleEquipped &&
            (bt & BT_USER1) != 0 &&
            onGround && !isSlamming);
        if (proneRequested)
        {
            if (!tlhProneActive)
            {
                tlhPronePreviousShadow = bShadow;
                tlhProneActive = true;
            }
            bShadow = true;
            Height = max(20.0, FullHeight * 0.48);
            Vel.XY *= 0.84;
        }
        else if (tlhProneActive)
        {
            tlhProneActive = false;
            bShadow = tlhPronePreviousShadow;
            Height = FullHeight * clamp(player.crouchfactor, 0.0, 1.0);
        }

        bool hunterRifleStealth = tlhProneActive && hunterRifleEquipped;
        if (hunterRifleStealth)
        {
            if (!tlhProneStealthActive)
            {
                tlhPronePreviousAlpha = Alpha;
                tlhPronePreviousMinVisible = bMinVisible;
                tlhProneStealthActive = true;
            }

            // Reduce pawn visibility and let hostile monsters fail their
            // normal visibility checks against the prone shooter.
            Alpha = min(tlhPronePreviousAlpha, 0.18);
            bShadow = true;
            // MINVISIBLE prevents hostile monsters from seeing the prone pawn.
            // Preserve it while prone, then restore the player's prior value.
            bMinVisible = true;
        }
        else if (tlhProneStealthActive)
        {
            Alpha = tlhPronePreviousAlpha;
            bMinVisible = tlhPronePreviousMinVisible;
            tlhProneStealthActive = false;
        }

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

        // Directional dash: Q (+user2), available on ground or in the air.
        // It preserves some incoming velocity and defaults to the facing direction.
        if (gameMode != 1 && tlhDashPressedThisTic &&
            tlhDashCooldown <= 0 && tlhSprintStamina >= 30.0 &&
            !tlhProneActive && !isSlamming && !tlhIsSliding &&
            player.PendingWeapon == WP_NOCHANGE)
        {
            double dashX = cos(angle) * forwardInput - sin(angle) * sideInput;
            double dashY = sin(angle) * forwardInput + cos(angle) * sideInput;
            double dashLength = sqrt(dashX * dashX + dashY * dashY);

            if (dashLength < 0.001)
            {
                dashX = cos(angle);
                dashY = sin(angle);
            }
            else
            {
                dashX /= dashLength;
                dashY /= dashLength;
            }

            Vel.XY = (Vel.X * 0.30 + dashX * 14.0,
                      Vel.Y * 0.30 + dashY * 14.0);
            double dashSpeed = Vel.XY.Length();
            if (dashSpeed > 19.0)
                Vel.XY *= 19.0 / dashSpeed;

            tlhSprintStamina = max(0.0, tlhSprintStamina - 30.0);
            tlhSprintRecoveryTics = 22;
            tlhDashTics = 6;
            tlhDashCooldown = 42;
            A_StartSound("weapons/sshotc", CHAN_BODY);
            Spawn("SlideSmoke", Pos - (0, 0, 18));
        }

        // Sprint uses the stock Run key and adds limited forward momentum.
        bool sprintRequested = gameMode != 1 &&
            (bt & BT_SPEED) != 0 && forwardInput > 0.0 &&
            onGround && !tlhProneActive && !isSlamming &&
            !tlhIsSliding && tlhDashTics == 0 &&
            tlhSprintStamina > 0.5;

        tlhIsSprinting = sprintRequested;
        if (sprintRequested)
        {
            Thrust(0.22, angle);
            if (sideInput != 0.0)
                Thrust(0.10 * sideInput, angle + 90.0);

            tlhSprintStamina = max(0.0, tlhSprintStamina - 0.48);
            tlhSprintRecoveryTics = 18;

            double sprintSpeed = Vel.XY.Length();
            if (sprintSpeed > 18.5)
                Vel.XY *= 18.5 / sprintSpeed;
        }
        else
        {
            if (tlhSprintRecoveryTics > 0)
                tlhSprintRecoveryTics--;
            else
                tlhSprintStamina = min(100.0,
                    tlhSprintStamina + (onGround ? 0.36 : 0.20));
        }

        // Mild air steering. Classic Doom, water, prone and slam states remain unchanged.
        if (gameMode != 1 && !onGround && !isSlamming &&
            !tlhProneActive && waterlevel == 0 && hasMoveInput)
        {
            if (forwardInput != 0.0)
                Thrust(0.10 * forwardInput, angle);
            if (sideInput != 0.0)
                Thrust(0.075 * sideInput, angle + 90.0);
        }

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
        // Shared cooldown for stance/mode and Dual Wield transitions.
        // ------------------------------------------------------------
        if (akimboCooldown > 0)
            akimboCooldown--;

        if (!(bt & BT_ZOOM))
            akimboButtonHeld = false;

        // ------------------------------------------------------------
        // Jump buffer, coyote jump, one midair jump and slide-hop.
        // A short buffer catches presses just before landing; coyote time
        // catches presses just after leaving a ledge.
        // ------------------------------------------------------------
        if (jumpPressed)
        {
            if (!onGround && gameMode != 1 && waterlevel == 0 && !isSlamming)
                tlhJumpBufferTics = 6;
            else
                tlhJumpBufferTics = 0;
        }
        else if (tlhJumpBufferTics > 0)
        {
            tlhJumpBufferTics--;
        }

        if (jumpPressed && onGround && tlhIsSliding &&
            gameMode != 1 && !isSlamming)
        {
            // Hop out of a slide while retaining most of its horizontal speed.
            tlhIsSliding = false;
            tlhSlideTics = 0;
            slideCooldown = max(slideCooldown, 18);
            Height = FullHeight * clamp(player.crouchfactor, 0.0, 1.0);
            Vel.Z = max(Vel.Z, 9.4);
            Vel.XY *= 1.10;
            double hopSpeed = Vel.XY.Length();
            if (hopSpeed > 21.5)
                Vel.XY *= 21.5 / hopSpeed;
            if (forwardInput > 0.0)
                Thrust(0.06, angle);
            tlhSprintStamina = max(0.0, tlhSprintStamina - 5.0);
            tlhCoyoteTics = 0;
            tlhJumpBufferTics = 0;
            jumpCount = 0;
            A_StartSound("weapons/sshotc", CHAN_BODY);
        }
        else if (tlhJumpBufferTics > 0 &&
            gameMode != 1 && !onGround && waterlevel == 0 && !isSlamming)
        {
            if (tlhCoyoteTics > 0)
            {
                Vel.Z = max(Vel.Z, 8.8);
                tlhCoyoteTics = 0;
                tlhJumpBufferTics = 0;
            }
            else if (jumpCount == 0)
            {
                Vel.Z = 12.0;
                jumpCount = 1;
                tlhJumpBufferTics = 0;
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
                tlhIsSliding = false;
                tlhSlideTics = 0;
                tlhSprintStamina = min(100.0, tlhSprintStamina + 10.0);
                maximumFallSpeed = 0;
                fallTicks = 0;
            }
            else if (!wasOnGround && maximumFallSpeed < -20.0)
            {
                Spawn("SlideSmoke", Pos - (0, 0, 20));
                A_StartSound("weapons/sshoto", CHAN_BODY);
            }

            // If jump was pressed shortly before touchdown, consume it now.
            // This creates a responsive landing hop without repeated auto-jumps.
            if (!wasOnGround && tlhJumpBufferTics > 0 &&
                gameMode != 1 && waterlevel == 0 && !isSlamming)
            {
                Vel.Z = max(Vel.Z, 8.8);
                jumpCount = 0;
                tlhCoyoteTics = 0;
                tlhJumpBufferTics = 0;

                double landingHopSpeed = Vel.XY.Length();
                if (landingHopSpeed > 5.0)
                {
                    Vel.XY *= 1.08;
                    if (Vel.XY.Length() > 20.5)
                        Vel.XY *= 20.5 / Vel.XY.Length();
                }
                A_StartSound("weapons/sshotc", CHAN_BODY);
            }

            if (!wasOnGround && (bt & BT_JUMP) && Vel.XY.Length() < 45.0)
            {
                Vel.XY *= 1.12;
                A_StartSound("weapons/sshotc", CHAN_BODY);
            }

            if (wasOnGround)
            {
                maximumFallSpeed = 0;
                fallTicks = 0;
            }
        }

        // ------------------------------------------------------------
        // Momentum slide / ground pound.
        // Ctrl (+crouch) is for the ground slide only. Ground Slam is
        // triggered exclusively by the configurable +user4 action.
        // ------------------------------------------------------------
        if (gameMode != 1 && onGround &&
            (bt & BT_CROUCH) && !(obt & BT_CROUCH))
        {
            double entrySpeed = Vel.XY.Length();
            if (entrySpeed >= 6.0 && slideCooldown <= 0 &&
                !tlhProneActive && tlhDashTics == 0)
            {
                tlhSlideTics = 26;
                tlhIsSliding = true;
                slideCooldown = 48;
                Vel.XY *= 1.16;

                double slideSpeed = Vel.XY.Length();
                if (slideSpeed > 20.0)
                    Vel.XY *= 20.0 / slideSpeed;

                Height = min(Height, FullHeight * 0.64);
                tlhSprintStamina = min(100.0, tlhSprintStamina + 4.0);
                A_StartSound("weapons/sshoto", CHAN_BODY);
                Spawn("SlideSmoke", Pos - (0, 0, 18));
            }
        }

        if (gameMode != 1 && groundSlamPressed && !onGround &&
            !isSlamming && !tlhProneActive)
        {
            Vel.XY *= 0.82;
            Vel.Z = -42.0;
            isSlamming = true;
            tlhDashTics = 0;
            A_StartSound("weapons/rocklf", CHAN_BODY);
        }

        if (tlhIsSliding)
        {
            if (!onGround || isSlamming || tlhSlideTics <= 0 ||
                Vel.XY.Length() < 4.0)
            {
                tlhIsSliding = false;
                tlhSlideTics = 0;
                Height = FullHeight * clamp(player.crouchfactor, 0.0, 1.0);
            }
            else
            {
                if (forwardInput > 0.0) Thrust(0.045, angle);
                if (sideInput != 0.0) Thrust(0.025 * sideInput, angle + 90.0);
                Vel.XY *= 0.988;
                Height = min(Height, FullHeight * 0.64);

                if ((level.maptime & 3) == 0)
                    Spawn("SlideSmoke", Pos - (0, 0, 18));
            }
        }
        else if (tlhSlideTics > 0)
        {
            tlhSlideTics = 0;
        }

        let m60 = M60MachineGun(player.ReadyWeapon);
        if (m60 && m60.braced && onGround)
            Vel.XY *= 0.84;

        // Feed the procedural camera/weapon animation state once per tic.
        UpdateTLHProceduralMotion(onGround, bt, obt);

        // Weapon HUD sprites receive no procedural position, scale or rotation.
        // Their original state offsets and GZDoom's native presentation remain.
        // Only the unlocked Simple Rifle palette translation is applied.
        PSprite weaponPSP = player.FindPSprite(PSP_WEAPON);
        PSprite flashPSP = player.FindPSprite(PSP_FLASH);

        if (weaponPSP) ApplyTLHWeaponPalette(weaponPSP);
        if (flashPSP) ApplyTLHWeaponPalette(flashPSP);

        // Duplicate the final visible primary frame on the mirrored layer.
        UpdateTLHDualWieldPresentation(weaponPSP);

        wasOnGround = onGround;
    }

    // Remove weapons only after neither the weapon switch nor a live PSprite
    // still references them. Game-mode loadouts may replace the current weapon.
    void CleanupDeferredWeaponRemovals()
    {
        PSprite weaponPSprite = player ? player.FindPSprite(PSP_WEAPON) : null;

        for (int i = 0; i < tlhDeferredWeaponRemovals.Size();)
        {
            Weapon oldWeapon = tlhDeferredWeaponRemovals[i];
            if (!oldWeapon)
            {
                tlhDeferredWeaponRemovals.Delete(i);
                continue;
            }

            if (player && (player.ReadyWeapon == oldWeapon ||
                player.PendingWeapon == oldWeapon ||
                (weaponPSprite && weaponPSprite.Caller == oldWeapon)))
            {
                i++;
                continue;
            }

            RemoveInventory(oldWeapon);
            oldWeapon.Destroy();
            tlhDeferredWeaponRemovals.Delete(i);
        }
    }

    // ========================================================================
    // PLAYER CORPSE SMELL REACTION
    // ========================================================================
    void UpdateTLHCorpseSmellReaction()
    {
        if (!player || player.playerstate != PST_LIVE || Health <= 0)
            return;

        if (tlhCorpseReactionSoundTics > 0)
        {
            tlhCorpseReactionSoundTics--;
            return;
        }

        // Avoid scanning every actor every tic on corpse-heavy maps.
        if (tlhCorpseScanCooldown > 0)
        {
            tlhCorpseScanCooldown--;
        }
        else
        {
            tlhCorpseScanCooldown = 7;
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
            }
            else if (closestCorpse != tlhCorpseReactionTarget)
            {
                tlhCorpseReactionTarget = closestCorpse;
                tlhCorpseReactionStayTics = 0;
                tlhCorpseReactionPlayed = false;
            }
        }

        if (!tlhCorpseReactionTarget || tlhCorpseReactionPlayed)
            return;

        // This counter still advances every tic; only the thinker scan is throttled.
        tlhCorpseReactionStayTics++;
        if (tlhCorpseReactionStayTics < 42)
            return;

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

    // Keep owned weapons on their original palette. Blue Simple Rifle colour
    // is applied to its weapon/flash PSprites only while that mode is unlocked.
    void RestoreTLHOwnedWeaponTranslations()
    {
        Inventory item = Inv;
        while (item)
        {
            Inventory nextItem = item.Inv;
            if (item is "Weapon" && item.Owner == self)
                item.Translation = 0;
            item = nextItem;
        }
    }

    // Apply weapon/flash/dual overlays from the player tick. PSpriteTick is
    // invoked on the overlay Caller (normally the weapon), not on this pawn.

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
        if (tlhProneActive)
            player.viewz -= clamp(FullHeight * 0.30, 10.0, 18.0);

        // Preserve GZDoom's normal collision safety after our extra visual bob.
        if (player.viewz > ceilingz - 4)
            player.viewz = ceilingz - 4;
        if (player.viewz < floorz + 4)
            player.viewz = floorz + 4;
    }

    // Weapon HUD PSprites are intentionally transform-free.
    // Position, scale, rotation, bob and offsets remain entirely authored by
    // the weapon states and GZDoom's native PSprite pipeline.
    // The only retained custom operation is the Simple Rifle palette.
    void ApplyTLHWeaponPalette(PSprite psp)
    {
        if (!psp || !player || !player.mo || !player.ReadyWeapon)
            return;

        Weapon weapon = player.ReadyWeapon;
        if (psp.Caller != weapon)
            return;

        psp.Translation = 0;

        if (weapon is "SimpleRifle" && tlhBlueSimpleRifleUnlocked)
        {
            TranslationID blueTint = Translate.GetID("BlueSimpleRifle");
            if (blueTint)
                psp.Translation = blueTint;
        }
    }


    int GetTLHAmmoSignature()
    {
        // A simple aggregate signature is used only for detecting a firing
        // event. Account for the Hunter Rifle's loaded magazine as well as
        // reserve inventories so a shot triggers the normal procedural recoil.
        int hunterRounds = 0;
        let hunter = HunterRifle(FindInventory("HunterRifle"));
        if (hunter) hunterRounds = hunter.magazineAmmo;

        // The revolver keeps its loaded cartridges in a script-side cylinder,
        // not in the reserve Clip inventory. Include it so firing either hand
        // still registers as a shot for procedural recoil.
        int revolverRounds = 0;
        let revolver = ServiceRevolver(FindInventory("ServiceRevolver"));
        if (revolver) revolverRounds = revolver.cylinderAmmo;

        return CountInv("Clip") + CountInv("Shell") +
               CountInv("RocketAmmo") + CountInv("Cell") +
               hunterRounds + revolverRounds;
    }

    void UpdateTLHProceduralMotion(bool onGroundNow, int bt, int oldbt)
    {
        // Advance weapon gait in the same Tick as the PSprite transform.
        double gaitSpeed = clamp(Vel.XY.Length() / 12.0, 0.0, 1.0);
        double gaitBobSpeed = clamp(player.GetWBobSpeed(), 0.45, 2.40);
        if (onGroundNow && gaitSpeed > 0.025 && !(player.cheats & CF_NOCLIP2))
            tlhAnimStepPhase += (6.0 + gaitSpeed * 12.0) * gaitBobSpeed;
        else
            tlhAnimStepPhase += 0.65 * gaitBobSpeed;
        while (tlhAnimStepPhase >= 36000.0) tlhAnimStepPhase -= 36000.0;
        while (tlhAnimStepPhase < 0.0) tlhAnimStepPhase += 36000.0;

        // ------------------------------------------------------------
        // Look inertia
        // ------------------------------------------------------------
        double targetLookX = clamp(double(player.cmd.yaw) / 48.0, -1.0, 1.0);
        double targetLookY = clamp(double(player.cmd.pitch) / 48.0, -1.0, 1.0);

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

        double targetSwayX = -sideVelocity * 0.145;
        double targetSwayY = abs(forwardVelocity) * 0.035;

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
            // Fresh weapon presentation: start slightly low, then let the
            // spring settle the weapon into the new stance.
            tlhAnimDrawKick = 5.0;
            tlhAnimDrawVel = 0.0;
        }

        // ------------------------------------------------------------
        // AMMO DELTA -> PHYSICAL PLAYER RECOIL
        // Camera pitch is handled by the weapon's authored A_SetPitch/A_Quake
        // calls. This block never changes a weapon PSprite.
        // ------------------------------------------------------------
        int ammoSignature = GetTLHAmmoSignature();

        if (tlhAnimLastAmmoSignature >= 0 &&
            ammoSignature < tlhAnimLastAmmoSignature)
        {
            int spent = tlhAnimLastAmmoSignature - ammoSignature;

            if (spent > 0 && spent < 96 && player.ReadyWeapon != null &&
                !(player.cheats & CF_NOCLIP2))
            {
                String cls = player.ReadyWeapon.GetClassName();
                double backwardPush = 0.0;

                // Small impulse for shotguns; substantial impulse only for
                // weapons whose discharge has enough force to move the shooter.
                if (cls == "RecoilShotgun")
                    backwardPush = 0.08;
                else if (cls == "SemiAutoShotgun")
                    backwardPush = 0.07;
                else if (cls == "FastRecoilSSG")
                    backwardPush = 0.18;
                else if (cls == "M60MachineGun")
                    backwardPush = 0.025;
                else if (cls == "HeavyChaingun")
                    backwardPush = 0.035;
                else if (cls == "RecoilRocketLauncher")
                    backwardPush = 0.42;
                else if (cls == "HellfireProjector")
                    backwardPush = 0.34;
                else if (cls == "AMR99RailRifle")
                    backwardPush = 0.24;
                else if (cls == "RecoilBFG9000")
                    backwardPush = 0.72;

                if (backwardPush > 0.0)
                {
                    double shotMultiplier = clamp(
                        0.90 + double(min(spent, 3)) * 0.08,
                        0.90, 1.14
                    );

                    double movementMultiplier = onGroundNow ? 1.0 : 0.72;
                    double physicalImpulse =
                        backwardPush * shotMultiplier * movementMultiplier;

                    if (tlhProneActive)
                        physicalImpulse *= 0.60;

                    // Apply velocity opposite to the player's facing direction.
                    Vel.X -= cos(angle) * physicalImpulse;
                    Vel.Y -= sin(angle) * physicalImpulse;
                }
            }
        }

        tlhAnimLastAmmoSignature = ammoSignature;

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
            int r = random(0, 8);
            if (r == 0) GiveModeWeaponLocal("RecoilPistol");
            else if (r == 1) GiveModeWeaponLocal("OfficerVulkanPistol");
            else if (r == 2) GiveModeWeaponLocal("RecoilShotgun");
            else if (r == 3) GiveModeWeaponLocal("TacticalM4A1");
            else if (r == 4) GiveModeWeaponLocal("HunterRifle");
            else if (r == 5) GiveModeWeaponLocal("HeavyChaingun");
            else if (r == 6) GiveModeWeaponLocal("M60MachineGun");
            else if (r == 7) GiveModeWeaponLocal("RecoilRocketLauncher");
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
        // Preserve both the equipped and previously pending weapon until the
        // PSprite has completed its switch to the destination weapon.
        Weapon oldPending = player ? player.PendingWeapon : null;

        if (!FindInventory(keep))
            GiveInventory(keep, 1);

        Weapon keepWeapon = Weapon(FindInventory(keep));
        if (player && keepWeapon)
            player.PendingWeapon = keepWeapon;

        Inventory item = Inv;
        while (item != null)
        {
            Inventory nextItem = item.Inv;
            if (item is "Weapon" && item.GetClassName() != keep)
            {
                Weapon candidate = Weapon(item);
                bool active = player && candidate &&
                    (player.ReadyWeapon == candidate ||
                     oldPending == candidate ||
                     player.PendingWeapon == candidate);

                if (active)
                    tlhDeferredWeaponRemovals.Push(candidate);
                else
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

            Actor mo = null;
            for (int attempt = 0; attempt < 8 && !mo; attempt++)
            {
                double a = FRandom(0, 360);
                double d = FRandom(192, 288);
                Vector3 spawnPos = (Pos.X + cos(a) * d, Pos.Y + sin(a) * d, Pos.Z);
                Actor candidate = Spawn(cls, spawnPos);

                if (candidate)
                {
                    candidate.FindFloorCeiling();
                    candidate.SetOrigin((candidate.Pos.X, candidate.Pos.Y,
                        candidate.floorz), true);

                    if (candidate.TestMobjLocation())
                        mo = candidate;
                    else
                        candidate.Destroy();
                }
            }

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
        if (FindInventory("SimpleRifle")) count++;
        if (FindInventory("FastRecoilSSG")) count++;
        if (FindInventory("TacticalM4A1")) count++;
        if (FindInventory("HunterRifle")) count++;
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
        if (selected == "" && FindInventory("SimpleRifle"))
        {
            if (pick == 1) selected = "SimpleRifle";
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
        if (selected == "" && FindInventory("HunterRifle"))
        {
            if (pick == 1) selected = "HunterRifle";
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
            A_SetPitch(pitch - 0.35, SPF_INTERPOLATE);
            
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
            A_SetPitch(pitch - 0.55, SPF_INTERPOLATE);
            A_SetPitch(pitch - 0.55, SPF_INTERPOLATE);
            A_SetPitch(pitch - 0.55, SPF_INTERPOLATE);
            
        }
        ZHGG B 1;
        ZHGG A 2
        {
            A_GunFlash();
            A_FireBullets(5.0, 3.0, 1, 5, "BulletPuff");
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            
        }
        ZHGG B 1;
        ZHGG A 2
        {
            A_GunFlash();
            A_FireBullets(5.0, 3.0, 1, 5, "BulletPuff");
            A_StartSound("weapons/sshotc", CHAN_WEAPON);
            
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

// Global DbyS (Damage by Sector) compatibility handler.
// GZDoom normally leaves monster damage opt-in for damaging sectors.
// Mark every positive-damage sector so monsters and decorations are harmed too.
// Strife-style delayed-damage sectors (SECF_HAZARD) are intentionally excluded.
class DbySSectorHandler : EventHandler
{
    String configuredMapName;

    override void WorldTick()
    {
        // Run once at the beginning of each map, including a restart of the
        // same map. Level.maptime is zero on its initial world tick.
        if (configuredMapName == level.MapName && level.maptime != 0)
            return;

        configuredMapName = level.MapName;

        for (int i = 0; i < level.Sectors.Size(); i++)
        {
            Sector sec = level.Sectors[i];
            if (sec.damageamount <= 0)
                continue;

            // UDMF specifies that hurtmonsters and damagehazard do not combine.
            if (sec.Flags & Sector.SECF_HAZARD)
                continue;

            sec.MoreFlags |= Sector.SECMF_HURTMONSTERS;
        }
    }
}

class TacticalHUDHandler : EventHandler
{
    // Universal active power-up countdown labels. PowerStrength is intentionally
    // omitted because vanilla Berserk does not have a normal expiry countdown.
    String GetPowerupHUDName(Powerup effect)
    {
        if (!effect) return "POWER-UP";
        String cls = effect.GetClassName();
        if (cls == "PowerInvulnerable") return "INVULNERABILITY";
        if (cls == "PowerInvisibility") return "INVISIBILITY";
        if (cls == "PowerIronFeet") return "RADIATION SUIT";
        if (cls == "PowerLightAmp") return "LIGHT AMP";
        if (cls == "PowerFlight") return "FLIGHT";
        if (cls == "PowerGhost") return "GHOST";
        if (cls == "PowerShadow") return "SHADOW";
        if (cls == "TLHAdrenalinePower") return "ADRENALINE";
        if (cls == "TLHJuggernautPower") return "JUGGERNAUT";
        if (cls == "PowerWeaponLevel2") return "POWER WEAPON";
        return cls;
    }

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
    int hudHunterAmmo;
    int hudHunterReserve;
    int hudShell;
    int hudRocket;
    int hudCell;
    int hudBlueSimpleRifleKills;
    bool hudBlueSimpleRifleUnlocked;

    // EventHandler-owned progress survives pawn death/respawn within a map.
    int tlhBlueSimpleRifleMapKills[MAXPLAYERS];
    bool tlhBlueSimpleRifleMapUnlocked[MAXPLAYERS];
    String tlhBlueSimpleRifleMapName[MAXPLAYERS];
    int hudWaterLevel;
    int hudWeaponHeat;
    double hudSprintStamina;
    bool hudIsSprinting;
    bool hudIsSliding;
    int hudDashTics;
    int hudDashCooldown;
    transient Array<String> hudPowerupNames;
    transient Array<int> hudPowerupTics;
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
    transient ui bool tlhDualBindKey1Down;
    transient ui bool tlhDualBindKey2Down;
    transient ui bool tlhGoreToggleDown;
    transient ui bool tlhGoreIntensityUpDown;
    transient ui bool tlhGoreIntensityDownDown;
    transient ui bool tlhGoreColorNextDown;
    transient ui String tlhInputLast;
    String tlhNoAvoidMeleeMapName;
    bool tlhNoAvoidMeleeScanned;
    transient ui Array<String> tlhInputHistory;
    transient ui String tlhHUDDualBindName;

    // Short, event-driven feedback indicators used by the compact HUD.
    int hudDamageFlashTics;
    int hudHealFlashTics;
    int hudHitmarkerTics;
    int hudKillConfirmTics;
    int hudHitDamage;
    String hudFeedbackText;
    int hudFeedbackTics;
    int hudFeedbackColor;
    int hudLastSampleHealth;
    bool hudHealthSampleReady;

    // Enemy/analyzer cache refresh interval. Rendering data does not need a
    // full thinker scan on every single game tic.
    int tlhHUDActorScanCooldown;

    // ------------------------------------------------------------------------
    // ANALYZER CACHE
    // ------------------------------------------------------------------------
    bool tlhVisorActive;
    int tlhVisorTime;
    String tlhVisorWeaponClass;
    transient Array<Actor> tlhVisorEnemies;
    transient Array<Actor> tlhMinimapEnemies;
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


    // Spawn additional TLH gore particles using local, persistent user CVars.
    // The vanilla blood system remains intact; these are configurable extras.
    void SpawnTLHGoreEffects(Actor victim, int damage, bool deathBurst)
    {
        if (!victim || !victim.bIsMonster ||
            consoleplayer < 0 || consoleplayer >= MAXPLAYERS)
            return;

        CVar enabled = CVar.GetCVar("tlh_gore_enabled", players[consoleplayer]);
        CVar intensityCVar = CVar.GetCVar("tlh_gore_intensity", players[consoleplayer]);
        CVar colorCVar = CVar.GetCVar("tlh_gore_color", players[consoleplayer]);

        if (!enabled || !enabled.GetBool() || !intensityCVar || !colorCVar)
            return;

        double intensity = clamp(intensityCVar.GetFloat(), 0.25, 2.0);
        int goreColor = clamp(colorCVar.GetInt(), 0, 3);

        TranslationID goreTranslation = 0;
        if (goreColor == 1)
            goreTranslation = Translate.GetID("TLHGoreGreen");
        else if (goreColor == 2)
            goreTranslation = Translate.GetID("TLHGoreBlue");
        else if (goreColor == 3)
            goreTranslation = Translate.GetID("TLHGorePurple");

        int particleCount;
        if (deathBurst)
            particleCount = int(ceil(2.0 + intensity * 3.5));
        else
            particleCount = int(ceil((0.45 + double(max(0, damage)) / 28.0) * intensity));

        particleCount = clamp(particleCount, 1, deathBurst ? 12 : 7);

        double bodyRadius = max(4.0, victim.Radius * 0.55);
        double bodyHeight = max(8.0, victim.Height * 0.78);
        double velocityScale = 0.75 + intensity * 0.55;
        double sizeScale = (0.80 + intensity * 0.20) * (deathBurst ? 1.25 : 1.0);

        for (int i = 0; i < particleCount; i++)
        {
            Vector3 spawnPos = victim.Pos + (
                FRandom(-bodyRadius, bodyRadius),
                FRandom(-bodyRadius, bodyRadius),
                FRandom(4.0, bodyHeight)
            );

            Actor gore = Actor.Spawn("TLHGoreParticle", spawnPos);
            if (!gore)
                continue;

            gore.Angle = FRandom(0.0, 360.0);
            gore.Vel = (
                FRandom(-2.2, 2.2) * velocityScale,
                FRandom(-2.2, 2.2) * velocityScale,
                FRandom(0.8, deathBurst ? 4.2 : 3.2) * velocityScale
            );
            gore.Scale = FRandom(0.18, 0.34) * sizeScale;

            if (goreTranslation)
                gore.Translation = goreTranslation;
        }
    }

    // KEYCONF routes these controls into this existing input observer.
    // CVars are user-scoped, so the settings stay local and persist per player.
    void ApplyTLHGoreControl(String command)
    {
        if (consoleplayer < 0 || consoleplayer >= MAXPLAYERS)
            return;

        PlayerInfo localPlayer = players[consoleplayer];
        CVar enabled = CVar.GetCVar("tlh_gore_enabled", localPlayer);
        CVar intensity = CVar.GetCVar("tlh_gore_intensity", localPlayer);
        CVar color = CVar.GetCVar("tlh_gore_color", localPlayer);
        Actor pawn = localPlayer.mo;

        if (!enabled || !intensity || !color)
            return;

        if (command ~== "tlh_gore_toggle")
        {
            enabled.SetBool(!enabled.GetBool());
            if (pawn)
                pawn.A_Print(enabled.GetBool() ? "TLH GORE: ENABLED" : "TLH GORE: DISABLED");
        }
        else if (command ~== "tlh_gore_intensity_up")
        {
            double value = clamp(intensity.GetFloat() + 0.25, 0.25, 2.0);
            intensity.SetFloat(value);
            if (pawn)
                pawn.A_Print(String.Format("GORE INTENSITY: %d%%", int(value * 100.0)));
        }
        else if (command ~== "tlh_gore_intensity_down")
        {
            double value = clamp(intensity.GetFloat() - 0.25, 0.25, 2.0);
            intensity.SetFloat(value);
            if (pawn)
                pawn.A_Print(String.Format("GORE INTENSITY: %d%%", int(value * 100.0)));
        }
        else if (command ~== "tlh_gore_color_next")
        {
            int nextColor = (color.GetInt() + 1) % 4;
            color.SetInt(nextColor);

            String colorName = "RED";
            if (nextColor == 1) colorName = "GREEN";
            else if (nextColor == 2) colorName = "BLUE";
            else if (nextColor == 3) colorName = "PURPLE";

            if (pawn)
                pawn.A_Print("GORE COLOR: " .. colorName);
        }
    }

    // Weapon-independent local-player hit and kill feedback.
    override void WorldThingDamaged(WorldEvent e)
    {
        if (e.Thing && e.Thing.bIsMonster && e.Damage > 0)
            SpawnTLHGoreEffects(e.Thing, e.Damage, false);

        if (!e.Thing || !e.Thing.bIsMonster || e.Thing.Health <= 0 ||
            !e.DamageSource || !e.DamageSource.player ||
            e.DamageSource.PlayerNumber() != consoleplayer)
            return;

        hudHitmarkerTics = 8;
        hudKillConfirmTics = 0;
        hudHitDamage = max(0, e.Damage);
    }

    override void WorldThingDied(WorldEvent e)
    {
        if (!e.Thing || !e.Thing.bIsMonster)
            return;

        SpawnTLHGoreEffects(e.Thing, 0, true);

        if (!e.DamageSource || !e.DamageSource.player)
            return;

        // Count the killer's Simple Rifle kills on the authoritative game side.
        int killerNum = e.DamageSource.PlayerNumber();
        if (killerNum >= 0 && killerNum < MAXPLAYERS)
        {
            if (tlhBlueSimpleRifleMapName[killerNum] != level.MapName)
            {
                tlhBlueSimpleRifleMapName[killerNum] = level.MapName;
                tlhBlueSimpleRifleMapKills[killerNum] = 0;
                tlhBlueSimpleRifleMapUnlocked[killerNum] = false;
            }

            Weapon killerWeapon = players[killerNum].ReadyWeapon;
            if (killerWeapon && killerWeapon is "SimpleRifle" &&
                !tlhBlueSimpleRifleMapUnlocked[killerNum])
            {
                tlhBlueSimpleRifleMapKills[killerNum] =
                    min(60, tlhBlueSimpleRifleMapKills[killerNum] + 1);

                Actor killerPawn = players[killerNum].mo;
                TacticalPlayer killer = TacticalPlayer(killerPawn);
                if (killer)
                {
                    killer.tlhBlueSimpleRifleMap = level.MapName;
                    killer.tlhBlueSimpleRifleKills = tlhBlueSimpleRifleMapKills[killerNum];
                }

                if (tlhBlueSimpleRifleMapKills[killerNum] >= 60)
                {
                    tlhBlueSimpleRifleMapUnlocked[killerNum] = true;
                    if (killer)
                        killer.tlhBlueSimpleRifleUnlocked = true;
                    if (killerPawn)
                    {
                        killerPawn.A_Print("\\c[Blue]BLUE SIMPLE RIFLE UNLOCKED: PLASMA RAIL MODE");
                        killerPawn.A_StartSound("weapons/railgf", CHAN_BODY);
                    }
                }
            }
        }

        // The visual kill confirmation is local-player-only.
        if (killerNum != consoleplayer)
            return;

        hudHitmarkerTics = 0;
        hudKillConfirmTics = 22;
        hudFeedbackText = "TARGET ELIMINATED";
        hudFeedbackTics = 24;
        hudFeedbackColor = 0xF2D36B;
    }

    override void WorldThingSpawned(WorldEvent e){
        if (!e.Thing) return;

        // Remove the MBF21 melee-avoidance behavior from every hostile monster,
        // including monsters created dynamically after the map has started.
        if (e.Thing.bIsMonster && !e.Thing.bFriendly)
            e.Thing.bAvoidMelee = false;

        // World pickups must use their original sprite palette. The class
        // defaults still carry the custom first-person translation.
        let worldWeapon = Weapon(e.Thing);
        if (worldWeapon && !worldWeapon.Owner)
            worldWeapon.Translation = 0;

        if (e.Thing is "HellfireProjector")
            e.Thing.Scale = (0.56, 0.56);

        let modeCvar = CVar.FindCVar("tlh_gamemode");
        int gameMode = modeCvar ? clamp(modeCvar.GetInt(), 0, 33) : 0;

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
                if (roll <= 17)
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


    override bool InputProcess(InputEvent e)
    {
        if (e.Type != InputEvent.Type_KeyDown &&
            e.Type != InputEvent.Type_KeyUp)
            return false;

        String keyName = e.KeyString;
        if (keyName == "")
            keyName = String.Format("KEY_%d", int(e.KeyScan));

        String historyKeyName = keyName;
        String binding = Bindings.GetBinding(e.KeyScan);
        bool inputDown = (e.Type == InputEvent.Type_KeyDown);

        if (binding ~== "+user3")
            tlhHUDDualBindName = keyName;

        if (binding != "")
            keyName = keyName .. " <" .. binding .. ">";

        if (inputDown)
        {
            tlhInputLast = "DOWN " .. keyName;
            tlhInputHistory.Push("DN  " .. historyKeyName);
        }
        else
        {
            tlhInputLast = "UP   " .. keyName;
            tlhInputHistory.Push("UP  " .. historyKeyName);
        }

        if (tlhInputHistory.Size() > 64)
            tlhInputHistory.Delete(0);

        if (e.KeyScan == InputEvent.KEY_MOUSE3 ||
            keyName ~== "MOUSE3" ||
            keyName ~== "MOUSE 3")
        {
            tlhInputM3Down = inputDown;
        }

        // Custom gore controls appear in Options > Customize Controls.
        // They use key-down latches so keyboard repeat never changes settings repeatedly.
        if (binding ~== "tlh_gore_toggle")
        {
            if (inputDown && !tlhGoreToggleDown)
            {
                tlhGoreToggleDown = true;
                ApplyTLHGoreControl(binding);
            }
            else if (!inputDown)
                tlhGoreToggleDown = false;
            return true;
        }
        if (binding ~== "tlh_gore_intensity_up")
        {
            if (inputDown && !tlhGoreIntensityUpDown)
            {
                tlhGoreIntensityUpDown = true;
                ApplyTLHGoreControl(binding);
            }
            else if (!inputDown)
                tlhGoreIntensityUpDown = false;
            return true;
        }
        if (binding ~== "tlh_gore_intensity_down")
        {
            if (inputDown && !tlhGoreIntensityDownDown)
            {
                tlhGoreIntensityDownDown = true;
                ApplyTLHGoreControl(binding);
            }
            else if (!inputDown)
                tlhGoreIntensityDownDown = false;
            return true;
        }
        if (binding ~== "tlh_gore_color_next")
        {
            if (inputDown && !tlhGoreColorNextDown)
            {
                tlhGoreColorNextDown = true;
                ApplyTLHGoreControl(binding);
            }
            else if (!inputDown)
                tlhGoreColorNextDown = false;
            return true;
        }

        // Read the user's live +user3 bindings, not a hardcoded physical key.
        // The UI-side latch suppresses OS key-repeat and rearms only on KeyUp.
        int dualKey1, dualKey2;
        [dualKey1, dualKey2] = Bindings.GetKeysForCommand("+user3");

        if (e.KeyScan == dualKey1 || e.KeyScan == dualKey2)
        {
            if (inputDown)
            {
                bool sendToggle = false;

                if (e.KeyScan == dualKey1 && !tlhDualBindKey1Down)
                {
                    tlhDualBindKey1Down = true;
                    sendToggle = true;
                }
                else if (e.KeyScan == dualKey2 && !tlhDualBindKey2Down)
                {
                    tlhDualBindKey2Down = true;
                    sendToggle = true;
                }

                if (sendToggle)
                    EventHandler.SendNetworkCommand('TLH_DualWieldToggle');
            }
            else
            {
                if (e.KeyScan == dualKey1)
                    tlhDualBindKey1Down = false;
                if (e.KeyScan == dualKey2)
                    tlhDualBindKey2Down = false;
            }

            // Consume this key so the old +user3 weapon-state dispatcher cannot run.
            return true;
        }

        return false;
    }

    override void NetworkCommandProcess(NetworkCommand cmd)
    {
        if (cmd.Command != 'TLH_DualWieldToggle')
            return;

        int playerNum = cmd.Player;
        if (playerNum < 0 || playerNum >= MAXPLAYERS)
            return;

        Actor pawn = players[playerNum].mo;
        if (!pawn || pawn.Health <= 0)
            return;

        TacticalPlayer tactical = TacticalPlayer(pawn);
        if (!tactical)
            return;

        Weapon weapon = players[playerNum].ReadyWeapon;
        if (!tactical.ToggleTLHDualWield(weapon))
        {
            if (!tactical.tlhDualWieldActive &&
                players[playerNum].PendingWeapon != WP_NOCHANGE)
                pawn.A_Print("DUAL WIELD: AUTO-DISABLED FOR WEAPON SWITCH");
            else
                pawn.A_Print("DUAL WIELD: CURRENT WEAPON UNSUPPORTED");
            return;
        }

        pawn.A_Print(tactical.tlhDualWieldActive
            ? "DUAL WIELD: ENABLED"
            : "DUAL WIELD: DISABLED");
        pawn.A_StartSound("weapons/sshotc", CHAN_BODY);
    }

    int GetTLHFaceHealthBand(Actor p)
    {
        if (!p || p.Health <= 0) return 4;

        int mode = 0;
        let c = CVar.FindCVar("tlh_gamemode");
        if (c) mode = clamp(c.GetInt(), 0, 33);

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

    void SyncBlueSimpleRifleProgress()
    {
        for (int i = 0; i < MAXPLAYERS; i++)
        {
            if (tlhBlueSimpleRifleMapName[i] != level.MapName)
            {
                tlhBlueSimpleRifleMapName[i] = level.MapName;
                tlhBlueSimpleRifleMapKills[i] = 0;
                tlhBlueSimpleRifleMapUnlocked[i] = false;
            }

            Actor pawn = players[i].mo;
            TacticalPlayer tp = TacticalPlayer(pawn);
            if (tp)
            {
                tp.tlhBlueSimpleRifleMap = level.MapName;
                tp.tlhBlueSimpleRifleKills = tlhBlueSimpleRifleMapKills[i];
                tp.tlhBlueSimpleRifleUnlocked = tlhBlueSimpleRifleMapUnlocked[i];
            }
        }
    }

    override void WorldTick(){
        SyncBlueSimpleRifleProgress();
        bool refreshHUDActorCache = (tlhHUDActorScanCooldown <= 0);
        if (refreshHUDActorCache)
            tlhHUDActorScanCooldown = 3;
        else
            tlhHUDActorScanCooldown--;

        if (hudDamageFlashTics > 0) hudDamageFlashTics--;
        if (hudHealFlashTics > 0) hudHealFlashTics--;
        if (hudHitmarkerTics > 0) hudHitmarkerTics--;
        if (hudKillConfirmTics > 0) hudKillConfirmTics--;
        if (hudFeedbackTics > 0) hudFeedbackTics--;

        // Rebuild the universal countdown cache every tic. It is only drawn
        // while one or more timed power-ups are actually active.
        hudPowerupNames.Clear();
        hudPowerupTics.Clear();

        // Clear AVOIDMELEE from monsters that were already present when the map
        // loaded. Rescan at map start/restart so existing actors are covered too.
        if (tlhNoAvoidMeleeMapName != level.MapName ||
            !tlhNoAvoidMeleeScanned || level.maptime == 0)
        {
            ThinkerIterator monsterScan = ThinkerIterator.Create("Actor");
            Actor scannedActor;
            while ((scannedActor = Actor(monsterScan.Next())) != null)
            {
                if (scannedActor.bIsMonster && !scannedActor.bFriendly)
                    scannedActor.bAvoidMelee = false;
            }
            tlhNoAvoidMeleeMapName = level.MapName;
            tlhNoAvoidMeleeScanned = true;
        }

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
        if (refreshHUDActorCache) hudLiveEnemies = 0;
        hudPlayerHealth = 0;
        hudArmor = 0;
        hudArmorMax = 0;
        hudClip = 0;
        hudRevolverAmmo = 0;
        hudRevolverReserve = 0;
        hudHunterAmmo = 0;
        hudHunterReserve = 0;
        hudShell = 0;
        hudRocket = 0;
        hudCell = 0;
        hudWeaponHeat = 0;
        hudSprintStamina = 100.0;
        hudIsSprinting = false;
        hudIsSliding = false;
        hudDashTics = 0;
        hudDashCooldown = 0;
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
        if (refreshHUDActorCache)
        {
            tlhVisorEnemies.Clear();
            tlhMinimapEnemies.Clear();
            tlhVisorWeapons.Clear();
            tlhVisorProjectiles.Clear();
            tlhVisorEnemyNames.Clear();
            tlhVisorWeaponNames.Clear();
        }
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

        // Every active timed Powerup subtype is included, including custom TLH
        // perks. EffectTics is already the remaining duration in engine tics.
        Inventory powerItem = p.Inv;
        while (powerItem != null)
        {
            Inventory nextPowerItem = powerItem.Inv;
            let activePower = Powerup(powerItem);
            if (activePower && activePower.EffectTics > 0 &&
                !(activePower is "PowerStrength"))
            {
                hudPowerupNames.Push(GetPowerupHUDName(activePower));
                hudPowerupTics.Push(activePower.EffectTics);
            }
            powerItem = nextPowerItem;
        }

        // Avoid querying a live PSprite/State while GZDoom changes weapons.
        // The engine keeps drawing the real weapon; the HUD preview is disabled
        // because reading its transient state here is unnecessary and fragile.
        hudWeaponTextureValid = false;
        hudWeaponTextureClass = "";
        hudWeaponFlip = false;

        int sampledHealth = max(0, p.Health);
        if (!hudHealthSampleReady || level.maptime == 0 ||
            (hudLastSampleHealth <= 0 && sampledHealth > 0))
        {
            hudLastSampleHealth = sampledHealth;
            hudHealthSampleReady = true;
        }
        else if (sampledHealth < hudLastSampleHealth)
        {
            int lostHealth = hudLastSampleHealth - sampledHealth;
            hudDamageFlashTics = max(hudDamageFlashTics, 10);
            hudFeedbackText = String.Format("DAMAGE -%d", lostHealth);
            hudFeedbackTics = 18;
            hudFeedbackColor = 0xD65B55;
            hudLastSampleHealth = sampledHealth;
        }
        else if (sampledHealth > hudLastSampleHealth)
        {
            int gainedHealth = sampledHealth - hudLastSampleHealth;
            hudHealFlashTics = max(hudHealFlashTics, 8);
            hudFeedbackText = String.Format("HEALTH +%d", gainedHealth);
            hudFeedbackTics = 18;
            hudFeedbackColor = 0x77C98A;
            hudLastSampleHealth = sampledHealth;
        }

        UpdateTLHDoomguyFace(p);
        tlhVisorPlayerDead = (p.player.playerstate == PST_DEAD);
        tlhVisorActive = p.FindInventory("PowerInvulnerable") != null;

        let tpState = TacticalPlayer(p);
        if (tpState)
        {
            tlhHUDDualActive = tpState.tlhDualWieldActive;
            hudBlueSimpleRifleKills = tpState.tlhBlueSimpleRifleKills;
            hudBlueSimpleRifleUnlocked = tpState.tlhBlueSimpleRifleUnlocked;
            hudSprintStamina = tpState.tlhSprintStamina;
            hudIsSprinting = tpState.tlhIsSprinting;
            hudIsSliding = tpState.tlhIsSliding;
            hudDashTics = tpState.tlhDashTics;
            hudDashCooldown = tpState.tlhDashCooldown;
        }

        hudPlayerHealth = max(0, p.Health);
        hudWaterLevel = p.waterlevel;
        hudFOV = clamp(double(p.player.FOV), 20.0, 160.0);
        hudMoveSpeed = sqrt(p.Vel.X * p.Vel.X + p.Vel.Y * p.Vel.Y);
        hudVerticalSpeed = p.Vel.Z;
        hudAltitude = max(0.0, p.Pos.Z - p.floorz);
        hudOnGround = (p.Pos.Z <= p.floorz + 0.5);
        let hudModeCvar = CVar.FindCVar("tlh_gamemode");
        int hudModeValue = hudModeCvar ? hudModeCvar.GetInt() : 0;
        hudModeName = GetGameModeName(clamp(hudModeValue, 0, 33));
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
                // tpState was null-checked above. Reuse that safe pointer here:
                // directly recasting and dereferencing TacticalPlayer(p) can
                // abort the VM with "tried to read from address zero".
                if (ssg && tpState && !tpState.tlhDualWieldActive)
                {
                    tlhSSGVisible = true;

                    tlhSSGOffsetX = 0;
                    tlhSSGOffsetY = 0;
                    tlhSSGRoll = 0;
                    tlhSSGRecoil = 0;
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
            else if (ready is "HunterRifle")
            {
                let hunter = HunterRifle(ready);
                if (hunter)
                {
                    hudHunterAmmo = hunter.magazineAmmo;
                    hudHunterReserve = hudClip;
                }
            }

            if (ready is "HeavyChaingun")
            {
                let chaingun = HeavyChaingun(ready);
                if (chaingun) hudWeaponHeat = chaingun.heat;
            }
if (hudWeaponName == "RecoilPistol") hudWeaponName = "RECOIL PISTOL";
            else if (hudWeaponName == "ServiceRevolver") hudWeaponName = "SERVICE REVOLVER";
            else if (hudWeaponName == "HunterRifle") hudWeaponName = "HUNTER RIFLE";
            else if (hudWeaponName == "OfficerVulkanPistol") hudWeaponName = "OFFICER VULKAN";
            else if (hudWeaponName == "RecoilShotgun") hudWeaponName = "COMBAT SHOTGUN";
            else if (hudWeaponName == "SimpleRifle") hudWeaponName = hudBlueSimpleRifleUnlocked ? "BLUE SIMPLE RIFLE" : "SIMPLE RIFLE";
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

        if (refreshHUDActorCache)
        {
        ThinkerIterator it = ThinkerIterator.Create("Actor");
        Actor mo;
        while ((mo = Actor(it.Next())) != null)
        {
            // Re-assert this for every live actor, not just at map start or
            // spawn time, so no hostile can regain MBF21 melee-avoidance dodging.
            if (mo.bIsMonster && !mo.bFriendly)
                mo.bAvoidMelee = false;

            if (mo.bIsMonster && mo.Health > 0)
            {
                hudLiveEnemies++;
                if (tlhMinimapEnemies.Size() < 64)
                {
                    double mdx = mo.Pos.X - p.Pos.X;
                    double mdy = mo.Pos.Y - p.Pos.Y;
                    if (mdx * mdx + mdy * mdy <= 1200.0 * 1200.0)
                        tlhMinimapEnemies.Push(mo);
                }

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
        out double accentStrength)
    {
        primary = 0xB8C0C2;
        secondary = 0x596164;
        accentStrength = 1.0;

        if (!weapon) return;

        String cls = weapon.GetClassName();

        if (cls == "OfficerVulkanPistol")
        {
            // Red/orange parts become steel-gray; original gray becomes darker.
            primary = 0x6E7775;
            secondary = 0x303735;
        }
        else if (cls == "SemiAutoShotgun")
        {
            // Muzzle/accent: controlled dark red, never neon.
            primary = 0x7B302D;
            secondary = 0x9B4240;
            accentStrength = 0.78;
        }
        else if (cls == "HeavyChaingun")
        {
            // Gunmetal body; red details stay red and are only slightly lifted.
            primary = 0x596260;
            secondary = 0x8D3A3A;
            accentStrength = 1.08;
        }
        else if (cls == "AMR99RailRifle")
        {
            // Lightened gray body + electric-blue BFG green-range accent.
            primary = 0xA4B0AD;
            secondary = 0x56B9D2;
            accentStrength = 1.10;
        }
        else if (cls == "HellfireProjector")
        {
            // Red nozzle + light-gray lower body.
            primary = 0xC53A35;
            secondary = 0xA5AFAD;
            accentStrength = 1.06;
        }
        else if (cls == "AirstrikeDesignator")
        {
            // Flare-red design with the same aspect-preserving sprite fit.
            primary = 0xC93E39;
            secondary = 0x7B302D;
            accentStrength = 1.06;
        }
        else if (cls == "RecoilPistol")
        {
            primary = 0x8B9693;
            secondary = 0x35413F;
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
        Color primary = 0xB8C0C2;
        Color secondary = 0x596164;
        double accentStrength = 1.0;

        GetHUDWeaponDesign(weapon, primary, secondary, accentStrength);

        // --------------------------------------------------------------------
        // SAFE CURRENT-STATE PREVIEW
        // --------------------------------------------------------------------
        // The actual PSprite frame was sampled in WorldTick() and cached for
        // this UI pass. No play-scoped Weapon state function is called here.
        TextureID tex;
        bool flip = false;

        // Do not query/draw CHGGA0 directly from this UI render path while the
        // weapon is changing. The engine draws the real HeavyChaingun PSprite;
        // this extra visor preview stays disabled until a stable texture cache
        // is available, avoiding crashes during weapon selection.
        if (hudWeaponTextureValid && hudWeaponTextureClass == cls)
        {
            tex = hudWeaponTexture;
            flip = hudWeaponFlip;
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

        double liveRoll = 0.0;
        double liveBobX = 0.0;
        double liveBobY = 0.0;

        // Fixed weapon preview; active recoil is camera-only.

        double fit = min(38.0 / tw, 23.0 / th);
        double dw = clamp(tw * fit, 18.0, 48.0);
        double dh = clamp(th * fit, 12.0, 30.0);

        double cx = 485.0 + liveBobX;
        double cy = 294.0 + liveBobY;

        // Keep the indexed sprite's original palette. Only the unlocked
        // SimpleRifle Blue mode supplies a non-zero translation index.
        int hudTranslation = 0;
        TacticalPlayer hudTactical = TacticalPlayer(p);
        if (weapon is "SimpleRifle" && hudTactical &&
            hudTactical.tlhBlueSimpleRifleUnlocked)
        {
            TranslationID blueHUDTranslation = Translate.GetID("BlueSimpleRifle");
            if (blueHUDTranslation)
                hudTranslation = int(blueHUDTranslation);
        }

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
    // UNIVERSAL POWER-UP COUNTDOWN
    // Hidden when no timed power-ups are active. Shows each remaining duration
    // as MM:SS; when the list is unusually long, the final row reports overflow.
    // ========================================================================

    ui void DrawPowerupTimers()
    {
        // This panel is strictly conditional: no timed power-up means no HUD
        // panel. The cache is rebuilt in WorldTick from every active Powerup.
        int count = hudPowerupNames.Size();
        if (count <= 0) return;

        Color main = 0x61C6B1;
        Color dim = 0x24443F;
        int visibleRows = min(count, 8);
        double panelHeight = 18.0 + visibleRows * 10.0;
        Panel(24, 143, 162, panelHeight, dim, 95);
        TextR("ACTIVE POWER-UPS", 179, 146, main, 0.22);

        for (int i = 0; i < visibleRows; i++)
        {
            double y = 157 + i * 10.0;
            if (count > 8 && i == 7)
            {
                Text(String.Format("+%d MORE ACTIVE", count - 7),
                    32, y, Font.CR_WHITE, 0.20);
                continue;
            }

            int remainingSeconds = (hudPowerupTics[i] + 34) / 35;
            int minutes = remainingSeconds / 60;
            int seconds = remainingSeconds % 60;
            int timerColor = remainingSeconds <= 10 ? Font.CR_RED :
                remainingSeconds <= 30 ? Font.CR_YELLOW : Font.CR_WHITE;

            Text(hudPowerupNames[i], 32, y, Font.CR_WHITE, 0.20);
            TextR(String.Format("%02d:%02d", minutes, seconds),
                179, y, timerColor, 0.20);
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
        else if (tlhVisorWeaponClass == "HunterRifle")
        {
            Text("MAGAZINE", 518, 306, dim, 0.21);
            TextR(String.Format("%02d/05", hudHunterAmmo), 609, 306,
                hudHunterAmmo <= 1 ? warn : Font.CR_WHITE, 0.25);
            Text("RESERVE", 518, 317, dim, 0.21);
            TextR(String.Format("%03d", hudHunterReserve), 609, 317, Font.CR_WHITE, 0.23);
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

        if (tlhVisorWeaponClass == "HeavyChaingun")
        {
            Text("HEAT", 518, 338, dim, 0.21);
            TextR(String.Format("%03d", int(clamp(double(hudWeaponHeat) / 3.0, 0.0, 100.0))),
                570, 338,
                hudWeaponHeat >= 250 ? Font.CR_RED :
                hudWeaponHeat >= 180 ? Font.CR_YELLOW : Font.CR_WHITE,
                0.23);
            SegBar(574, 340, 35, hudWeaponHeat, 300, 5,
                hudWeaponHeat >= 250 ? 0xC65B55 :
                hudWeaponHeat >= 180 ? warn : main);
        }
        else
        {
            Text("LINK", 518, 338, dim, 0.21);
            TextR(tlhHUDDualActive ? "AKIMBO" : "NORMAL", 609, 338,
                tlhHUDDualActive ? Font.CR_GREEN : dim, 0.21);
        }
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


    // Large, readable key register placed in the free right-side visor area.
    ui void DrawInputMonitor()
    {
        Color frame = 0x46545A;
        Color dim = 0x526067;
        Color active = 0x32AFFF;

        Panel(444, 143, 172, 115, frame, 135);
        Text("INPUT LOGGER", 452, 147, Font.CR_WHITE, 0.43);
        TextR("LIVE", 608, 147, active, 0.38);

        int bt = 0;
        if (consoleplayer >= 0 && consoleplayer < MAXPLAYERS)
        {
            let p = players[consoleplayer].mo;
            if (p && p.player)
                bt = p.player.cmd.buttons;
        }

        Text("MOVE", 452, 160, dim, 0.32);
        Text("W", 495, 160, (bt & BT_FORWARD) ? active : Font.CR_WHITE, 0.38);
        Text("A", 514, 160, (bt & BT_MOVELEFT) ? active : Font.CR_WHITE, 0.38);
        Text("S", 533, 160, (bt & BT_BACK) ? active : Font.CR_WHITE, 0.38);
        Text("D", 552, 160, (bt & BT_MOVERIGHT) ? active : Font.CR_WHITE, 0.38);
        Text("SP", 573, 160, (bt & BT_JUMP) ? active : Font.CR_WHITE, 0.32);
        Text("CT", 594, 160, (bt & BT_CROUCH) ? active : Font.CR_WHITE, 0.32);

        Text("ACT", 452, 173, dim, 0.32);
        Text("J", 482, 173, (bt & BT_JUMP) ? active : Font.CR_WHITE, 0.34);
        Text("C", 497, 173, (bt & BT_CROUCH) ? active : Font.CR_WHITE, 0.34);
        Text("M1", 514, 173, (bt & BT_ATTACK) ? active : Font.CR_WHITE, 0.32);
        Text("M2", 537, 173, (bt & BT_ALTATTACK) ? active : Font.CR_WHITE, 0.32);
        Text("M3", 560, 173, tlhInputM3Down ? active : Font.CR_WHITE, 0.32);
        Text("R", 586, 173, (bt & BT_RELOAD) ? active : Font.CR_WHITE, 0.34);

        Line(452, 184, 608, 184, frame, 170, 0.65);
        Text("RECENT KEY EVENTS", 452, 188, Font.CR_WHITE, 0.38);

        int count = tlhInputHistory.Size();
        int rows = min(6, count);
        if (rows <= 0)
        {
            Text("WAITING FOR INPUT...", 452, 204, dim, 0.32);
        }
        else
        {
            for (int i = 0; i < rows; i++)
            {
                int historyIndex = count - rows + i;
                int eventColor = (i == rows - 1) ? Font.CR_YELLOW : Font.CR_WHITE;
                Text(tlhInputHistory[historyIndex], 452, 199 + i * 9,
                    eventColor, 0.42);
            }
        }
    }

    // ========================================================================
    // ROOT YARBIS VISOR
    // ========================================================================


    // =========================================================================
    // COMPACT HUD // PRESERVES THE DATA, REDUCES SCREEN OCCUPANCY
    // The detailed legacy draw methods remain in the class for compatibility;
    // the active overlay uses this smaller layout.
    // =========================================================================

    ui void DrawCompactHeader()
    {
        Color main = 0xC1C8CA;
        Color dim = 0x667176;
        Color accent = 0x8DA6AB;

        Text("TLH", 8, 7, main, 0.30);
        Text(hudMapName, 29, 8, dim, 0.23);
        TextC(hudModeName, 320, 8, accent, 0.22);
        TextR(String.Format("%02d:%02d", (hudMapTime / 35) / 60,
            (hudMapTime / 35) % 60), 632, 8, main, 0.24);
        Line(8, 18, 632, 18, dim, 105, 0.55);
    }

    ui void DrawCompactInput()
    {
        int bt = 0;
        if (consoleplayer >= 0 && consoleplayer < MAXPLAYERS)
        {
            let p = players[consoleplayer].mo;
            if (p && p.player) bt = p.player.cmd.buttons;
        }

        Color active = 0x32AFFF;
        int idle = 0x667176;
        Text("W", 8, 23, (bt & BT_FORWARD) ? active : idle, 0.22);
        Text("A", 20, 23, (bt & BT_MOVELEFT) ? active : idle, 0.22);
        Text("S", 32, 23, (bt & BT_BACK) ? active : idle, 0.22);
        Text("D", 44, 23, (bt & BT_MOVERIGHT) ? active : idle, 0.22);
        Text("SP", 59, 23, (bt & BT_JUMP) ? active : idle, 0.20);
        Text("CT", 78, 23, (bt & BT_CROUCH) ? active : idle, 0.20);
        Text("M1", 98, 23, (bt & BT_ATTACK) ? active : idle, 0.20);
        Text("M2", 119, 23, (bt & BT_ALTATTACK) ? active : idle, 0.20);
        Text("M3", 140, 23, tlhInputM3Down ? active : idle, 0.20);
        Text("R", 162, 23, (bt & BT_RELOAD) ? active : idle, 0.22);

        String recent = "INPUT READY";
        int count = tlhInputHistory.Size();
        if (count > 0) recent = tlhInputHistory[count - 1];
        TextR(recent, 632, 23, idle, 0.20);
    }

    // Keep a short rolling input history visible without restoring the old,
    // oversized right-side logger panel.
    ui void DrawCompactInputHistory()
    {
        int count = tlhInputHistory.Size();
        int rows = min(4, count);
        for (int i = 0; i < rows; i++)
        {
            int index = count - rows + i;
            int color = (i == rows - 1) ? Font.CR_WHITE : 0x667176;
            TextR(tlhInputHistory[index], 632, 32 + i * 7.0,
                color, 0.18);
        }
    }

    ui void DrawCompactMovementStatus()
    {
        int stamina = int(clamp(hudSprintStamina, 0.0, 100.0));
        int stateColor = 0x7E969C;
        String movementState = "DASH READY";

        if (hudDashTics > 0)
        {
            movementState = "DASH";
            stateColor = 0xE2D18B;
        }
        else if (hudIsSliding)
        {
            movementState = "SLIDE";
            stateColor = 0xE2D18B;
        }
        else if (hudIsSprinting)
        {
            movementState = "SPRINT";
            stateColor = 0x83C99B;
        }
        else if (hudDashCooldown > 0)
        {
            movementState = String.Format("DASH %02d",
                (hudDashCooldown + 34) / 35);
        }

        TextC(String.Format("%s  //  STAMINA %03d%%",
            movementState, stamina), 320, 37, stateColor, 0.21);
        SegBar(286, 45, 68, stamina, 100, 8,
            stamina <= 20 ? 0xD65B55 :
            stamina <= 45 ? 0xD3B35B : 0x77C98A);
    }

    ui void DrawCompactPowerupTimers()
    {
        int count = hudPowerupNames.Size();
        if (count <= 0) return;

        int label = 0x89969A;
        int dim = 0x4D585C;
        Text("POWER", 8, 59, label, 0.21);
        int rows = min(count, 4);
        for (int i = 0; i < rows; i++)
        {
            int seconds = max(0, (hudPowerupTics[i] + 34) / 35);
            int timerColor = seconds <= 10 ? Font.CR_RED :
                seconds <= 30 ? Font.CR_YELLOW : Font.CR_WHITE;
            double y = 70 + i * 9.0;
            Text(hudPowerupNames[i], 8, y, dim, 0.19);
            TextR(String.Format("%02d:%02d", seconds / 60, seconds % 60),
                154, y, timerColor, 0.19);
        }
        if (count > rows)
            Text(String.Format("+%d MORE", count - rows), 8,
                70 + rows * 9.0, dim, 0.18);
    }

    ui void DrawCompactTelemetry()
    {
        int dim = 0x667176;
        int main = 0xB8C0C2;
        int alert = 0xD3B35B;
        TextR(String.Format("FOV %03d  VEL %03d", int(hudFOV),
            int(hudMoveSpeed)), 632, 59, main, 0.21);
        TextR(String.Format("ALT %04d  VZ %+04d", int(hudAltitude),
            int(hudVerticalSpeed)), 632, 70, dim, 0.20);
        TextR(hudOnGround ? "GROUND" : "AIRBORNE", 632, 81,
            hudOnGround ? dim : alert, 0.20);
        TextR(tlhVisorActive ? "TACTICAL SCAN ACTIVE" : "VISOR STANDBY",
            632, 92, tlhVisorActive ? 0x77C98A : dim, 0.19);
    }

    ui void DrawCompactVitals()
    {
        int dim = 0x667176;
        int main = 0xB8C0C2;
        int hpColor = hudPlayerHealth < 40 ? 0xD65B55 : main;
        int armorColor = hudArmor < 50 ? 0xD3B35B : 0x6E9EAD;

        Line(8, 292, 154, 292, dim, 120, 0.6);
        Text("HP", 8, 299, dim, 0.21);
        TextR(String.Format("%03d", max(0, hudPlayerHealth)), 43, 299,
            hudPlayerHealth < 40 ? Font.CR_RED : Font.CR_WHITE, 0.24);
        SegBar(49, 303, 102, hudPlayerHealth, TLH_MAX_HEALTH, 10, hpColor);

        Text("ARM", 8, 315, dim, 0.21);
        TextR(String.Format("%03d", max(0, hudArmor)), 43, 315,
            hudArmor < 50 ? Font.CR_YELLOW : Font.CR_WHITE, 0.23);
        SegBar(49, 319, 102, hudArmor, max(1, hudArmorMax), 10, armorColor);

        Text(hudOnGround ? "GND" : "AIR", 8, 333,
            hudOnGround ? main : 0xD3B35B, 0.19);
        Text(String.Format("VZ %+04d", int(hudVerticalSpeed)),
            43, 333, dim, 0.19);
    }

    ui void DrawCompactCombat()
    {
        int dim = 0x667176;
        int main = 0xB8C0C2;
        int warn = 0xD3B35B;

        Line(486, 292, 632, 292, dim, 120, 0.6);
        TextR(hudWeaponName, 632, 298, main, 0.22);

        if (tlhVisorWeaponClass == "ServiceRevolver")
        {
            TextR(String.Format("CYL %02d/06   RES %03d",
                hudRevolverAmmo, hudRevolverReserve), 632, 310,
                hudRevolverAmmo <= 1 ? warn : Font.CR_WHITE, 0.20);
        }
        else if (tlhVisorWeaponClass == "HunterRifle")
        {
            TextR(String.Format("MAG %02d/05   RES %03d",
                hudHunterAmmo, hudHunterReserve), 632, 310,
                hudHunterAmmo <= 1 ? warn : Font.CR_WHITE, 0.20);
        }
        else
        {
            TextR(String.Format("BUL %03d  SHE %03d",
                hudClip, hudShell), 632, 310, Font.CR_WHITE, 0.20);
            TextR(String.Format("RCK %03d  CEL %03d",
                hudRocket, hudCell), 632, 320, Font.CR_WHITE, 0.20);
        }

        TextR(String.Format("HOST %03d  DOWN %03d/%03d",
            hudLiveEnemies, hudKills, hudTotalEnemies),
            632, 331, hudLiveEnemies > 0 ? Font.CR_RED : dim, 0.19);

        if (tlhVisorWeaponClass == "SimpleRifle")
        {
            TextR(hudBlueSimpleRifleUnlocked ? "BLUE RAIL MODE // CELL AMMO" :
                String.Format("BLUE SIMPLE RIFLE %02d/60", hudBlueSimpleRifleKills),
                632, 342, hudBlueSimpleRifleUnlocked ? 0x48BFFF : 0x8A9DA3, 0.19);
            if (!hudBlueSimpleRifleUnlocked)
                SegBar(574, 349, 54, hudBlueSimpleRifleKills, 60, 8, 0x48BFFF);
        }

        if (tlhVisorWeaponClass == "HeavyChaingun")
        {
            TextR(String.Format("HEAT %03d%%",
                int(clamp(double(hudWeaponHeat) / 3.0, 0.0, 100.0))),
                632, 341,
                hudWeaponHeat >= 250 ? Font.CR_RED :
                hudWeaponHeat >= 180 ? Font.CR_YELLOW : main, 0.19);
            SegBar(586, 348, 42, hudWeaponHeat, 300, 6,
                hudWeaponHeat >= 250 ? 0xC65B55 :
                hudWeaponHeat >= 180 ? warn : 0x61C6B1);
        }
        else
        {
            TextR(tlhHUDDualActive ? "AKIMBO" : "SINGLE",
                632, 341, tlhHUDDualActive ? Font.CR_GREEN : dim, 0.19);
        }
    }

    ui void DrawCompactFeedback()
    {
        int red = 0xD65B55;
        int green = 0x77C98A;
        int yellow = 0xF2D36B;

        if (hudDamageFlashTics > 0)
        {
            int alpha = min(150, hudDamageFlashTics * 13);
            Line(8, 5, 58, 5, red, alpha, 1.4);
            Line(582, 5, 632, 5, red, alpha, 1.4);
            Line(8, 355, 58, 355, red, alpha, 1.4);
            Line(582, 355, 632, 355, red, alpha, 1.4);
        }
        else if (hudHealFlashTics > 0)
        {
            int alpha = min(130, hudHealFlashTics * 15);
            Line(8, 355, 72, 355, green, alpha, 1.2);
        }

        if (hudPlayerHealth > 0 && hudPlayerHealth < 30)
        {
            int pulse = 55 + int(35.0 * (0.5 + 0.5 *
                sin(double(tlhVisorTime) * 0.18 * TLH_RAD_TO_DEG)));
            Line(8, 12, 20, 12, red, pulse, 1.2);
            Line(620, 12, 632, 12, red, pulse, 1.2);
        }

        if (hudHitmarkerTics > 0 || hudKillConfirmTics > 0)
        {
            int marker = hudKillConfirmTics > 0 ? yellow : Font.CR_WHITE;
            double size = hudKillConfirmTics > 0 ? 6.0 : 4.0;
            Line(320 - size, 180 - size, 318, 178, marker, 220, 1.0);
            Line(320 + size, 180 - size, 322, 178, marker, 220, 1.0);
            Line(320 - size, 180 + size, 318, 182, marker, 220, 1.0);
            Line(320 + size, 180 + size, 322, 182, marker, 220, 1.0);
            if (hudKillConfirmTics > 0)
                TextC("KILL", 320, 194, yellow, 0.22);
            else
                TextC(String.Format("-%d", hudHitDamage), 320, 194,
                    Font.CR_WHITE, 0.19);
        }

        if (hudFeedbackTics > 0 && hudFeedbackText != "")
            TextC(hudFeedbackText, 320, 54, hudFeedbackColor, 0.23);
    }

    ui void DrawTacticalMinimap(Actor p)
    {
        if (!p) return;
        double x0 = 8, y0 = 112, w = 94, h = 72;
        Color frame = 0x6B8990;
        Color grid = 0x34474D;
        Panel(x0, y0, w, h, frame, 155);
        Text("LOCAL MAP", x0 + 5, y0 + 4, 0xA9C0C5, 0.19);
        Line(x0 + w * 0.5, y0 + 15, x0 + w * 0.5, y0 + h - 4, grid, 120, 0.5);
        Line(x0 + 4, y0 + 43, x0 + w - 4, y0 + 43, grid, 120, 0.5);
        double ca = cos(p.Angle);
        double sa = sin(p.Angle);
        for (int i = 0; i < tlhMinimapEnemies.Size(); i++)
        {
            Actor enemy = tlhMinimapEnemies[i];
            if (!enemy || enemy.Health <= 0) continue;
            double dx = enemy.Pos.X - p.Pos.X;
            double dy = enemy.Pos.Y - p.Pos.Y;
            double forward = dx * ca + dy * sa;
            double side = -dx * sa + dy * ca;
            double mx = x0 + w * 0.5 + side * 0.045;
            double my = y0 + 43 - forward * 0.045;
            if (mx < x0 + 3 || mx > x0 + w - 3 || my < y0 + 16 || my > y0 + h - 3)
                continue;
            Line(mx - 1.2, my, mx + 1.2, my, 0xE16A60, 220, 1.0);
            Line(mx, my - 1.2, mx, my + 1.2, 0xE16A60, 220, 1.0);
        }
        Line(x0 + w * 0.5, y0 + 37, x0 + w * 0.5 - 3.2, y0 + 45, 0x66D6C8, 240, 1.1);
        Line(x0 + w * 0.5, y0 + 37, x0 + w * 0.5 + 3.2, y0 + 45, 0x66D6C8, 240, 1.1);
        Line(x0 + w * 0.5 - 3.2, y0 + 45, x0 + w * 0.5 + 3.2, y0 + 45, 0x66D6C8, 240, 1.1);
        TextR(String.Format("%02d", tlhMinimapEnemies.Size()), x0 + w - 5, y0 + 4, 0xE16A60, 0.19);
    }

    ui void DrawPseudoShaderOverlay(Actor p)
    {
        if (!p) return;
        int pulse = 28 + int(18.0 * (0.5 + 0.5 *
            sin(double(level.time) * 0.11 * TLH_RAD_TO_DEG)));
        Color edge = 0x6B9AA2;
        if (hudPlayerHealth > 0 && hudPlayerHealth < 35)
        {
            edge = 0xC94E4A;
            pulse = 48 + int(45.0 * (0.5 + 0.5 *
                sin(double(level.time) * 0.19 * TLH_RAD_TO_DEG)));
        }
        else if (hudWaterLevel > 0)
        {
            edge = 0x3C9FC7;
            pulse = 42;
        }
        Line(0, 0, 640, 0, edge, pulse, 2.0);
        Line(0, 360, 640, 360, edge, pulse, 2.0);
        Line(0, 0, 0, 360, edge, pulse, 2.0);
        Line(640, 0, 640, 360, edge, pulse, 2.0);
        if (hudWaterLevel > 0)
        {
            for (int i = 0; i < 5; i++)
            {
                double y = 92 + ((level.time * 0.7 + i * 47) % 170);
                Line(110, y, 530, y, 0x4BAACB, 18, 0.45);
            }
        }
        else
        {
            for (int i = 0; i < 3; i++)
            {
                double y = 126 + i * 54 + ((level.time + i * 13) % 18);
                Line(2, y, 638, y, 0xA8C0C5, 9, 0.35);
            }
        }
    }

    override void RenderOverlay(RenderEvent e)
    {
        if (consoleplayer < 0 || consoleplayer >= MAXPLAYERS) return;

        let p = players[consoleplayer].mo;
        if (!p || !p.player) return;

        DrawCompactHeader();
        DrawCompactInput();
        DrawCompactInputHistory();
        DrawCompactMovementStatus();
        DrawCompactPowerupTimers();
        DrawCompactTelemetry();
        DrawCompactVitals();
        DrawCompactCombat();
        DrawFaceNode();
        DrawPeripheralAnalyzer(e);
        DrawSSGChainCompact();
        DrawAimTargetLabel(p, e);
        DrawTacticalMinimap(p);
        DrawCompactFeedback();
        DrawPseudoShaderOverlay(p);
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
                drop = Spawn("SimpleRifle", Pos);
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
        FastSpeed 11;
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
        FastSpeed 10;
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
        FastSpeed 17;
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
