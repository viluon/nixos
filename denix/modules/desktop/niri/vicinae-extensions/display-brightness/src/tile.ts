import { type Palette } from "./palette";

const width = 320;
const height = 180;
const barX = 40;
const barWidth = width - 2 * barX;

function screen(isInternal: boolean, { frame }: Palette): string {
  const outline = `fill="none" stroke="${frame}" stroke-width="6"`;
  return isInternal
    ? `<rect x="70" y="14" width="180" height="104" rx="8" ${outline}/>
       <path d="M50 124 H270 L284 136 H36 Z" fill="${frame}"/>`
    : `<rect x="60" y="10" width="200" height="112" rx="8" ${outline}/>
       <rect x="150" y="122" width="20" height="10" fill="${frame}"/>
       <rect x="120" y="130" width="80" height="6" rx="3" fill="${frame}"/>`;
}

export function brightnessTile(
  percent: number,
  isInternal: boolean,
  palette: Palette,
): string {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
    ${screen(isInternal, palette)}
    <rect x="${barX}" y="152" width="${barWidth}" height="14" rx="7" fill="${palette.track}"/>
    <rect x="${barX}" y="152" width="${(barWidth * percent) / 100}" height="14" rx="7" fill="${palette.accent}"/>
  </svg>`;
  return `data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`;
}
