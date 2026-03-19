#include <metal_stdlib>
using namespace metal;

// ─────────────────────────────────────────────────────────────
//  Orb.metal — GPU shader for the Orion Orb animation
//  Phase 4: Metal GPU orb, activated via is_metal_orb_enabled flag
// ─────────────────────────────────────────────────────────────

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct OrbUniforms {
    float time;
    float audioLevel;
    int   visualState;  // 0=idle  1=listening  2=processing  3=error
    int   padding;
};

// ─────────────────────────────────────────────────────────────
//  Vertex — full-screen quad passthrough
// ─────────────────────────────────────────────────────────────

vertex VertexOut orbVertex(
    uint              vertexID  [[vertex_id]],
    device const float2* verts [[buffer(0)]]
) {
    VertexOut out;
    out.position = float4(verts[vertexID], 0.0, 1.0);
    // remap NDC [-1,1] → UV [0,1]
    out.uv = verts[vertexID] * 0.5 + 0.5;
    return out;
}

// ─────────────────────────────────────────────────────────────
//  Fragment — procedural orb
// ─────────────────────────────────────────────────────────────

fragment float4 orbFragment(
    VertexOut          in       [[stage_in]],
    constant OrbUniforms& u     [[buffer(0)]]
) {
    // Centered UV in [-1, 1]
    float2 uv   = in.uv * 2.0 - 1.0;
    float  dist = length(uv);

    // ── Breathing ───────────────────────────────────────────
    float breathe = sin(u.time * 1.35) * 0.65 + sin(u.time * 2.45 + 0.9) * 0.35;
    float motionAmp;
    if (u.visualState == 1) {         // listening
        motionAmp = 0.028 + u.audioLevel * 0.020;
    } else if (u.visualState == 2) {  // processing
        motionAmp = 0.021;
    } else if (u.visualState == 3) {  // error
        motionAmp = 0.012;
    } else {                          // idle
        motionAmp = 0.016;
    }
    float orbRadius = 0.72 + breathe * motionAmp;

    // ── Smooth circle SDF ───────────────────────────────────
    float aa        = fwidth(dist) * 2.0;  // anti-alias width
    float circle    = smoothstep(orbRadius + aa, orbRadius - aa, dist);

    // ── State colours ───────────────────────────────────────
    float3 outerColor, innerColor, glowTint;
    if (u.visualState == 1) {                // listening
        outerColor = float3(0.074, 0.114, 0.235);
        innerColor = float3(0.149, 0.196, 0.376);
        glowTint   = float3(0.40, 0.55, 0.88);
    } else if (u.visualState == 2) {         // processing
        outerColor = float3(0.106, 0.137, 0.235);
        innerColor = float3(0.169, 0.216, 0.376);
        glowTint   = float3(0.38, 0.50, 0.82);
    } else if (u.visualState == 3) {         // error
        outerColor = float3(0.50,  0.04,  0.04);
        innerColor = float3(0.72,  0.10,  0.10);
        glowTint   = float3(1.0,   0.20,  0.20);
    } else {                                 // idle
        outerColor = float3(0.063, 0.102, 0.176);
        innerColor = float3(0.125, 0.157, 0.282);
        glowTint   = float3(0.42, 0.48, 0.78);
    }

    // Radial gradient inside orb
    float radialT   = 1.0 - saturate(dist / orbRadius);
    float3 orbColor = mix(outerColor, innerColor, radialT * radialT);

    // ── Specular highlight (top-left) ───────────────────────
    float2 lightOff = uv - float2(-0.30, 0.26);
    float  spec     = 1.0 - saturate(length(lightOff) / 0.42);
    orbColor       += spec * spec * 0.20;

    // ── Glow ring ────────────────────────────────────────────
    float glowWidth = 0.06;
    float ring      = smoothstep(orbRadius + glowWidth, orbRadius + aa, dist)
                    - (1.0 - circle);
    float glowStr;
    if (u.visualState == 1) {
        glowStr = 0.40 + u.audioLevel * 0.16;
    } else if (u.visualState == 2) {
        glowStr = 0.30;
    } else if (u.visualState == 3) {
        glowStr = 0.85;
    } else {
        glowStr = 0.20;
    }

    // ── Compose ──────────────────────────────────────────────
    float3 finalColor = orbColor * circle + glowTint * ring * glowStr;
    float  alpha      = saturate(circle + ring * glowStr * 0.5);

    // Premultiply alpha for correct blending
    return float4(finalColor * alpha, alpha);
}
