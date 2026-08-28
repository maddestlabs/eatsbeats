#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_mode;          // 0: Custom, 1: B&W, 2: Protanopia, 3: Deuteranopia, 4: Tritanopia, 5: High Contrast, 6: Light-Sensitive Muted
uniform float u_intensity;     // 0.0 - 1.0 filter blend amount
uniform float u_brightness;    // 0.5 - 1.5 (default 1.0)
uniform float u_contrast;      // 0.5 - 2.0 (default 1.0)
uniform float u_saturation;    // 0.0 - 2.0 (default 1.0)
uniform float u_beat_pulse;    // 0.0 - 1.0 (audio reactivity)
uniform float u_bass_energy;   // 0.0 - 1.0 (audio reactivity)

uniform sampler2D u_texture;

out vec4 fragColor;

// LMS color blindness simulation matrices (Brettel / Machado standard)
mat3 protanopiaMatrix = mat3(
    0.56667, 0.43333, 0.0,
    0.55833, 0.44167, 0.0,
    0.0,     0.24167, 0.75833
);

mat3 deuteranopiaMatrix = mat3(
    0.625, 0.375, 0.0,
    0.70,  0.30,  0.0,
    0.0,   0.30,  0.70
);

mat3 tritanopiaMatrix = mat3(
    0.95, 0.05,  0.0,
    0.0,  0.43333, 0.56667,
    0.0,  0.475, 0.525
);

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution;
    vec4 baseTex = texture(u_texture, uv);
    vec3 col = baseTex.rgb;

    int mode = int(u_mode + 0.5);

    if (mode == 1) {
        // Black & White / Monochromatic
        float gray = dot(col, vec3(0.299, 0.587, 0.114));
        col = mix(col, vec3(gray), u_intensity);
    } else if (mode == 2) {
        // Protanopia (Red-Blind)
        vec3 sim = protanopiaMatrix * col;
        col = mix(col, sim, u_intensity);
    } else if (mode == 3) {
        // Deuteranopia (Green-Blind)
        vec3 sim = deuteranopiaMatrix * col;
        col = mix(col, sim, u_intensity);
    } else if (mode == 4) {
        // Tritanopia (Blue-Blind)
        vec3 sim = tritanopiaMatrix * col;
        col = mix(col, sim, u_intensity);
    } else if (mode == 5) {
        // High Contrast / Vivid
        vec3 gray = vec3(dot(col, vec3(0.299, 0.587, 0.114)));
        vec3 boosted = mix(gray, col, 1.4);
        boosted = (boosted - 0.5) * 1.3 + 0.5;
        col = mix(col, clamp(boosted, 0.0, 1.0), u_intensity);
    } else if (mode == 6) {
        // Light-Sensitive Muted (Warm tone down, reduced glare & gamma)
        col = pow(col, vec3(1.15)) * vec3(0.85, 0.82, 0.78);
        float gray = dot(col, vec3(0.299, 0.587, 0.114));
        col = mix(col, vec3(gray) * vec3(0.9, 0.85, 0.8), 0.25 * u_intensity);
    }

    // Manual Brightness, Contrast & Saturation tuning
    if (abs(u_brightness - 1.0) > 0.01) {
        col *= u_brightness;
    }
    if (abs(u_contrast - 1.0) > 0.01) {
        col = (col - 0.5) * u_contrast + 0.5;
    }
    if (abs(u_saturation - 1.0) > 0.01) {
        float gray = dot(col, vec3(0.299, 0.587, 0.114));
        col = mix(vec3(gray), col, u_saturation);
    }

    fragColor = vec4(clamp(col, 0.0, 1.0), baseTex.a);
}
