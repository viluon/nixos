vec4 open_color(vec3 coords_geo, vec3 size_geo) {
    float p = niri_progress;

    float scale_y = mix(0.5, 1.0, p);

    float wave_delay = coords_geo.y * coords_geo.y * coords_geo.y * 0.9;
    float local_p = clamp((p - wave_delay) / (1.0 - wave_delay), 0.0, 1.0);
    float scale_x = max(0.01, mix(0.05, 1.0, local_p));

    float offset_x = (coords_geo.x - 0.5) / scale_x + 0.5;
    float offset_y = (coords_geo.y - 0.5) / scale_y + 0.5;

    vec3 coords_tex = niri_geo_to_tex * vec3(offset_x, offset_y, 1.0);
    vec4 color = texture2D(niri_tex, coords_tex.st);

    color *= niri_clamped_progress;
    return color;
}
