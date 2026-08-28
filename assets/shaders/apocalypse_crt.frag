#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;

// Visual Effects
uniform float u_grille_level;     // 0.0 - 3.0 (default 0.95)
uniform float u_grille_density;   // 100.0 - 1200.0 (default 800.0)
uniform float u_scanline_level;   // 0.0 - 3.0 (default 0.80)
uniform float u_scanlines;        // 0.5 - 4.0 (default 1.0)
uniform float u_rgb_offset;       // 0.0 - 0.008 (default 0.001)

// Distortion & Motion
uniform float u_curve_strength;   // 0.0 - 2.0 (default 0.35)
uniform float u_curve_distance;   // 1.0 - 5.0 (default 2.5)
uniform float u_noise_level;      // 0.0 - 1.0 (default 0.10)
uniform float u_flicker;          // 0.0 - 1.0 (default 0.15)
uniform float u_h_sync;           // 0.0 - 2.0 (default 0.02)
uniform float u_rumble;           // 0.0 - 2.0 (default 1.0)

// Environmental Light & Frame
uniform float u_light_speed;      // 0.0 - 2.0 (default 1.0)
uniform float u_frame_size;       // 0.0 - 50.0 (default 18.0 px)
uniform float u_frame_hue;        // 0.0 - 1.0 (default 0.025)
uniform float u_frame_sat;        // 0.0 - 1.0 (default 0.10)
uniform float u_frame_light;      // 0.0 - 0.20 (default 0.05)
uniform float u_frame_reflect;    // 0.0 - 1.0 (default 0.60)
uniform float u_frame_grain;      // 0.0 - 0.50 (default 0.15)

// Color & Tinting
uniform float u_glass_tint;       // 0.0 - 1.0 (default 0.15)
uniform float u_glass_hue;        // 0.0 - 1.0 (default 0.33)
uniform float u_glass_sat;        // 0.0 - 1.0 (default 0.30)
uniform float u_screen_tint;      // 0.0 - 1.0 (default 0.0)
uniform float u_screen_hue;       // 0.0 - 1.0 (default 0.0)
uniform float u_screen_sat;       // 0.0 - 2.0 (default 1.0)

// Audio Reactivity
uniform float u_beat_pulse;       // 0.0 - 1.0
uniform float u_bass_energy;      // 0.0 - 1.0

uniform sampler2D u_texture;

out vec4 fragColor;

float rnd(vec2 c) {
    return fract(sin(dot(c.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 hsl2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Sample content texture with RGB chromatic aberration shift
vec3 rgbDistortion(vec2 uv, float offset) {
    vec3 col;
    col.r = texture(u_texture, uv + vec2(offset, 0.0)).r;
    col.g = texture(u_texture, uv).g;
    col.b = texture(u_texture, uv - vec2(offset, 0.0)).b;
    return col;
}

// Dynamic swaying light source illuminating the curved CRT tube & bezel
float calculateLightFactor(vec2 uv, float time) {
    float intensity = 1.5;
    float ambientLight = 0.35;

    // Moving swaying light arc
    float lightX = 0.5 + sin(time * 1.75) * 0.35;
    vec2 lightPos = vec2(lightX, 0.15);

    vec2 lightVector = uv - lightPos;
    float scaledDistance = length(lightVector);

    float lightFalloff = pow(clamp(1.0 - (scaledDistance / 1.5), 0.0, 1.0), 0.85);
    return mix(ambientLight, 1.0 + intensity, lightFalloff);
}

// Render main screen tube graphics (scanlines, phosphor grille, tint, flicker, noise)
vec3 sampleScreen(vec2 uv, float hWave, float rgbOff) {
    vec2 screenUv = uv;
    screenUv.x += hWave;

    if (screenUv.x < 0.0 || screenUv.x > 1.0 || screenUv.y < 0.0 || screenUv.y > 1.0) {
        return vec3(0.015, 0.018, 0.024);
    }

    vec3 col = rgbDistortion(screenUv, rgbOff);

    // Aperture Phosphor Grille
    if (u_grille_level > 0.0) {
        float grillePattern = sin(uv.x * u_grille_density * 3.14159265);
        grillePattern = u_grille_level + (1.0 - u_grille_level) * grillePattern;
        col *= (0.5 + 0.5 * grillePattern);
    }

    // Horizontal Scanlines
    if (u_scanline_level > 0.05) {
        float scanlinePattern = sin(uv.y * u_resolution.y * 3.14159265 / max(0.1, u_scanlines));
        col *= (u_scanline_level + (1.0 - u_scanline_level) * scanlinePattern);
    }

    // High frequency analog noise
    if (u_noise_level > 0.0) {
        float n = rnd(uv + fract(u_time * 1.2));
        col += n * u_noise_level * 0.08;
    }

    // Screen color tinting & saturation
    if (u_screen_tint > 0.0 || abs(u_screen_sat - 1.0) > 0.01) {
        float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
        vec3 tinted = hsl2rgb(vec3(u_screen_hue, u_screen_sat, lum));
        col = mix(col, tinted, u_screen_tint);
    }

    // Glass phosphor reflection / tinting
    if (u_glass_tint > 0.0) {
        float t = 0.5 + 0.5 * uv.y;
        vec3 glassColor = hsl2rgb(vec3(u_glass_hue, u_glass_sat, t));
        col += glassColor * u_glass_tint * 0.4;
    }

    // 60Hz power supply flicker
    if (u_flicker > 0.0) {
        float f = 1.0 + 0.03 * sin(u_time * 60.0) * u_flicker;
        col *= f;
    }

    // Vignette
    vec2 vUv = uv * (1.0 - uv.yx);
    float vignette = vUv.x * vUv.y * 20.0;
    col *= clamp(pow(vignette, 0.25), 0.0, 1.0);

    return col;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution;

    // 1. Periodic Rumble & Jitter (from original HLSL)
    float rumbleDim = 0.0;
    if (u_rumble > 0.0) {
        float hash = fract(sin(floor(u_time / 7.0) * 43758.5453));
        float interval = 7.0 + hash * 6.0;
        float currentIntervalStart = floor(u_time / interval) * interval;
        float phase = u_time - currentIntervalStart;
        float rumbleDuration = 1.0;

        if (phase < rumbleDuration) {
            float rumbleStrength = sin(phase * 3.14159265 / rumbleDuration) * u_rumble;
            rumbleDim = 0.05 * rumbleStrength;
            vec2 rumbleOffset = vec2(
                sin(u_time * 20.0 + 0.3) * cos(u_time * 13.0),
                cos(u_time * 17.0 - 0.7) * sin(u_time * 11.0)
            ) * rumbleStrength * 2.5 / u_resolution;
            uv += rumbleOffset;
        }
    }

    // 2. Periodic H-Sync Jitter Wave
    float hWave = 0.0;
    if (u_h_sync > 0.0) {
        float cyclePeriod = 2.0;
        float randomOffset = fract(sin(floor(u_time / cyclePeriod) * 12345.67) * 43758.5453);
        float actualCyclePeriod = cyclePeriod + randomOffset;
        float cyclePosition = fract(u_time / actualCyclePeriod);
        if (cyclePosition < 0.15) {
            float normTime = cyclePosition / 0.15;
            float waveStrength = sin(normTime * 3.14159265) * u_h_sync * 0.02;
            hWave = sin(uv.y * 10.0 + u_time * 5.0) * waveStrength;
        }
    }

    // 3. Barrel Curvature Distortion with distance power
    vec2 center = vec2(0.5, 0.5);
    float distFromCenter = length(uv - center);
    float curStrength = u_curve_strength + (u_bass_energy * 0.03);

    if (curStrength > 0.001) {
        uv += (uv - center) * pow(distFromCenter, max(1.0, u_curve_distance)) * curStrength;
    }

    // 4. Virtual CRT Frame & Bezel calculation
    vec2 pxSize = 1.0 / u_resolution;
    float frame = u_frame_size * pxSize.x;
    vec2 suv = (uv - vec2(frame, frame)) / max(vec2(0.001), 1.0 - 2.0 * vec2(frame, frame));

    bool isFrame = (uv.x < frame || uv.x > (1.0 - frame) || uv.y < frame || uv.y > (1.0 - frame));
    float rgbOff = u_rgb_offset + (u_beat_pulse * 0.0015);

    vec3 color;

    if (isFrame && u_frame_size > 0.5) {
        // === CRT BEZEL PLASTIC FRAME WITH MIRRORED SCREEN REFLECTION ===
        float distX = min(uv.x, 1.0 - uv.x);
        float distY = min(uv.y, 1.0 - uv.y);
        float minDist = min(distX, distY);
        float frameDepth = max(frame * 4.0, 0.001);
        float intensity = mix(u_frame_light, 0.005, clamp(minDist / frameDepth, 0.0, 1.0));

        // Mirror UV coordinate for reflection onto bezel
        vec2 reflectedUV = suv;
        if (reflectedUV.x < 0.0) reflectedUV.x = -reflectedUV.x;
        else if (reflectedUV.x > 1.0) reflectedUV.x = 2.0 - reflectedUV.x;

        if (reflectedUV.y < 0.0) reflectedUV.y = -reflectedUV.y;
        else if (reflectedUV.y > 1.0) reflectedUV.y = 2.0 - reflectedUV.y;

        // Multi-tap blur of mirrored screen content reflected on bezel
        vec3 blurredReflection = vec3(0.0);
        float blurRadius = 3.0 / u_resolution.x;
        blurredReflection += texture(u_texture, clamp(reflectedUV + vec2(-blurRadius, 0.0), 0.0, 1.0)).rgb;
        blurredReflection += texture(u_texture, clamp(reflectedUV + vec2(blurRadius, 0.0), 0.0, 1.0)).rgb;
        blurredReflection += texture(u_texture, clamp(reflectedUV + vec2(0.0, -blurRadius), 0.0, 1.0)).rgb;
        blurredReflection += texture(u_texture, clamp(reflectedUV + vec2(0.0, blurRadius), 0.0, 1.0)).rgb;
        blurredReflection += texture(u_texture, clamp(reflectedUV, 0.0, 1.0)).rgb;
        blurredReflection /= 5.0;

        // Frame plastic base color + grain
        color = hsl2rgb(vec3(u_frame_hue, u_frame_sat, intensity));
        color *= (1.0 - u_frame_grain * rnd(uv * 2.0));

        // Blend blurred screen reflection onto frame
        color += blurredReflection * (u_frame_reflect * 0.45);

        // Environmental moving light reflection on the bezel
        if (u_light_speed > 0.0) {
            float lightFactor = calculateLightFactor(uv, u_time * u_light_speed);
            vec3 warmLight = vec3(1.0, 0.98, 0.95);
            color *= warmLight * lightFactor;
        }
    } else {
        // === MAIN CRT TUBE SCREEN AREA ===
        color = sampleScreen(suv, hWave, rgbOff);

        // Environmental moving light reflection across the tube glass
        if (u_light_speed > 0.0) {
            float lightFactor = calculateLightFactor(suv, u_time * u_light_speed);
            vec3 warmLight = vec3(1.0, 0.98, 0.95);
            color *= warmLight * lightFactor;
        }
    }

    // Apply rumble dim
    color -= vec3(rumbleDim);

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
