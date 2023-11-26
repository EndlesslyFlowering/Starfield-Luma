/*  OpenDRT -------------------------------------------------/
      v0.2.8
      Written by Jed Smith
      https://github.com/jedypod/open-display-transform

      License: GPL v3
-------------------------------------------------*/

// Gamut Conversion Matrices

/* Math helper functions ----------------------------*/


// Safe division of float a by float b
float sdivf(float a, float b) {
  if (b == 0.0f) return 0.0f;
  else return b ? a/b : 0;
}

// Safe division of float3 a by float b
float3 sdivf3f(float3 a, float b) {
  return float3(sdivf(a.x, b), sdivf(a.y, b), sdivf(a.z, b));
}

// Safe division of float3 a by float3 b
float3 sdivf3f3(float3 a, float3 b) {
  return float3(sdivf(a.x, b.x), sdivf(a.y, b.y), sdivf(a.z, b.z));
}

// Safe power function raising float a to power float b
float spowf(float a, float b) {
  if (a <= 0.0f) return a;
  else return pow(a, b);
}

// Safe power function raising float3 a to power float b
float3 spowf3(float3 a, float b) {
  return float3(pow(a.x, b), pow(a.y, b), pow(a.z, b));
}

// Return max of float3 a and float mn
float3 maxf3(float mn, float3 a) { return float3(max(a.x, mn), max(a.y, mn), max(a.z, mn)); }

// Return min of float3 a and float mx
float3 minf3(float mx, float3 a) { return float3(min(a.x, mx), min(a.y, mx), min(a.z, mx)); }

// Return the hypot or length of float3 a
float hypotf3(float3 a) { return  sqrt(spowf(a.x, 2.0f) + spowf(a.y, 2.0f) + spowf(a.z, 2.0f)); }

float3 narrow_hue_angles(float3 v) {
  return float3(
    min(2.0f, max(0.0f, v.x - (v.y + v.z))),
    min(2.0f, max(0.0f, v.y - (v.x + v.z))),
    min(2.0f, max(0.0f, v.z - (v.x + v.y))));
}

float tonescale(float x, float m, float s, float c) {
  return spowf(m*x/(x + s), c);
}

float tonescale_invert(float x, float m, float s, float c) {
  float ip = 1.0f/c;
  return spowf(s*x, ip)/(m - spowf(x, ip));
}

float flare(float x, float fl) {
  return spowf(x, 2.0f)/(x+fl);
}

float flare_invert(float x, float fl) {
  return (x + sqrt(x*(4.0f*fl + x)))/2.0f;
}

// https://www.desmos.com/calculator/gfubm2kvlu
float powerp(float x, float p, float m) {
  float y = x <= 0.0f ? x : x*spowf(spowf(x/m, 1.0f/p) + 1.0f, -p);
  return y;
}

// https://www.desmos.com/calculator/jrff9lrztn
float powerptoe(float x, float p, float m, float t0) {
  float y = x > t0 ? x : (x-t0)*spowf(spowf((t0-x)/(t0-m), 1.0f/p) + 1.0f, -p) + t0;
  return y;
}

/* Shadow Contrast
    Invertible cubic shadow exposure function
    https://www.desmos.com/calculator/ubgteikoke
    https://colab.research.google.com/drive/1JT_-S96RZyfHPkZ620QUPIRfxmS_rKlx
*/
float3 shd_con(float3 rgb, float ex, float str) {
  // Parameter setup
  const float m = pow(2.0f, ex);
  const float w = pow(str, 3.0f);

  float n = max(rgb.x, max(rgb.y, rgb.z));
  float n2 = n*n;
  float s;
  s = (n2 + m*w)/(n2 + w); // Implicit divide by n
  rgb *= s;
  return rgb;
}

float3 shd_con_invert(float3 rgb, float ex, float str) {
  // Parameter setup
  const float m = pow(2.0f, ex);
  const float w = pow(str, 3.0f);

  float n = max(rgb.x, max(rgb.y, rgb.z));
  float n2 = n*n;
  float s;
  float p0 = n2 - 3.0f*m*w;
  float p1 = 2.0f*n2 + 27.0f*w - 9.0f*m*w;
  float p2 = pow(sqrt(n2*p1*p1 - 4*p0*p0*p0)/2.0f + n*p1/2.0f,1.0f/3.0f);
  s = (p0/(3.0f*p2) + p2/3.0f + n/3.0f) / n;
  rgb *= s;
  return rgb;
}

/* Highlight Contrast
    Invertible quadratic highlight contrast function. Same as ex_high without lin ext
    https://www.desmos.com/calculator/p7j4udnwkm
*/
float3 hl_con(float3 rgb, float ex, float th) {
  // Parameter setup
  float p = pow(2.0f, -ex);
  float t0 = 0.18f*pow(2.0f, th);
  float a = pow(t0, 1.0f - p)/p;
  float b = t0*(1.0f - 1.0f/p);

  float n = max(rgb.x, max(rgb.y, rgb.z));
  float s;
  if (n == 0.0f || n < t0) {
    s = 1.0f;
  } else {
    s = pow((n - b)/a, 1.0f/p)/n;
  }
  return rgb * s;
}

/* Highlight Contrast
    Invertible quadratic highlight contrast function. Same as ex_high without lin ext
    https://www.desmos.com/calculator/p7j4udnwkm
*/
float3 hl_con_invert(float3 rgb, float ex, float th) {
  // Parameter setup
  float p = pow(2.0f, -ex);
  float t0 = 0.18f*pow(2.0f, th);
  float a = pow(t0, 1.0f - p)/p;
  float b = t0*(1.0f - 1.0f/p);

  float n = max(rgb.x, max(rgb.y, rgb.z));
  float s;
  if (n == 0.0f || n < t0) {
    s = 1.0f;
  } else {
    s = (a*pow(n, p) + b)/n;
  }
  return rgb * s;
}

float3 zone_extract(float3 input, float3 rgb, float zp, int zr) {
  float n = max(1e-12f, max(rgb.x, max(rgb.y, rgb.z)));
  const float fl = 0.01f;
  float zpow = pow(2.0f, -zp + 1.0f);
  float toe = (n * n / (n + fl));
  float f = pow((toe / (toe + 1.0f)) / n, zpow);
  if (zr == 1) f = 1.0f - pow((n / (n + 1.0f)) / n, zpow);
  return input * (1.0f - f) + rgb * f;
}

float3 ex_high(float3 rgb, float ex, float pv, float fa) {
  // Zoned highlight exposure with falloff : https://www.desmos.com/calculator/ylq5yvkhoq

  // Parameter setup
  const float f = 5.0f * pow(fa, 1.6f) + 1.0f;
  const float p = abs(ex + f) < 1e-8f ? 1e-8f : (ex + f) / f;
  const float m = pow(2.0f, ex);
  const float t0 = 0.18f * pow(2.0f, pv);
  const float a = pow(t0, 1.0f - p) / p;
  const float b = t0 * (1.0f - 1.0f / p);
  const float x1 = t0 * pow(2.0f, f);
  const float y1 = a * pow(x1, p) + b;

  // Calculate scale factor for rgb
  float n = max(rgb.x, max(rgb.y, rgb.z));
  float s;
  s = n < t0 ? 1.0f : n > x1 ? (m * (n - x1) + y1) / n : (a * pow(n, p) + b) / n;
  return rgb * s;
}

float3 ex_high_invert(float3 rgb, float ex, float pv, float fa) {
  // Zoned highlight exposure with falloff : https://www.desmos.com/calculator/ylq5yvkhoq

  // Parameter setup
  const float f = 5.0f * pow(fa, 1.6f) + 1.0f;
  const float p = abs(ex + f) < 1e-8f ? 1e-8f : (ex + f) / f;
  const float m = pow(2.0f, ex);
  const float t0 = 0.18f * pow(2.0f, pv);
  const float a = pow(t0, 1.0f - p) / p;
  const float b = t0 * (1.0f - 1.0f / p);
  const float x1 = t0 * pow(2.0f, f);
  const float y1 = a * pow(x1, p) + b;

  // Calculate scale factor for rgb
  float n = max(rgb.x, max(rgb.y, rgb.z));
  float s;
  s = n < t0 ? 1.0f : n > y1 ? ((m * x1 - y1 + n) / m) / n : pow((n - b) / a, 1.0f / p) / n;
  return rgb * s;
}

// Calculate classical HSV-style "chroma"
float calc_chroma(float3 rgb) {
  float mx = max(rgb.x, max(rgb.y, rgb.z));
  float mn = min(rgb.x, min(rgb.y, rgb.z));
  float ch = mx - mn;
  return sdivf(ch, mx);
}

float calc_hue(float3 rgb) {
  float mx = max(rgb.x, max(rgb.y, rgb.z));
  float mn = min(rgb.x, min(rgb.y, rgb.z));
  float ch = mx - mn;
  float h;
  if (ch == 0.0f) h = 0.0f;
  else if (mx == rgb.x) h = ((rgb.y - rgb.z) / ch + 6.0f) % 6.0f;
  else if (mx == rgb.y) h = (rgb.z - rgb.x) / ch + 2.0f;
  else if (mx == rgb.z) h = (rgb.x - rgb.y) / ch + 4.0f;
  return h;
}

// Extract a range from e0 to e1 from f, clamping values above or below.
float extract(float e0, float e1, float x) {
  return clamp((x - e0) / (e1 - e0), 0.0f, 1.0f);
}

// Linear window function to extract a range from float x: https://www.desmos.com/calculator/uzsk5ta5v7
float extract_window(float e0, float e1, float e2, float e3, float x) {
  return x < e1 ? extract(e0, e1, x) : extract(e3, e2, x);
}

float extract_hue_angle(float h, float o, float w, int sm) {
  float hc = extract_window(2.0f - w, 2.0f, 2.0f, 2.0f + w, (h + o) % 6.0f);
  if (sm == 1)
    hc = hc * hc * (3.0f - 2.0f * hc); // smoothstep
  return hc;
}

float3 n6_hueshift(float3 rgb, 
    float sy, float sr, float sm, float sb, float sc, float sg,
    float scu, float cuh, float cuw,
    float str, float chl, int ze, float zp, int zr) {
  
  float3 input = rgb;

  // max(r,g,b) norm
  float n = max(rgb.x, max(rgb.y, rgb.z));
  
  // RGB Ratios
  float3 r;
  if (n == 0.0f) r = float3(0.0f, 0.0f, 0.0f);
  else r = rgb / n;
 
  // Chroma
  // Strength controls a lerp between min(r,g,b) and max(r,g,b) for the calculation of chroma
  float ch = min(r.x, min(r.y, r.z)) * (1.0f - str) + str;
  ch = ch == 0.0f ? 0.0f : min(1.0f, 1.0f - min(r.x / ch, min(r.y / ch, r.z / ch)));
  
  // Chroma limit: reduces effect on more saturated colors, depending on chroma limit strength
  // 0.5 < chl < 1 : power function on limit
  // 0 < chl < 0.5 : mix back limit (better handles out of gamut colorimetry)
  float f0 = chl < 0.5f ? max(0.0f, 0.5f - chl) * 2.0f : 1.0f / max(1e-3f, (1.0f - chl) * 2.0f);
  ch = chl < 0.5f ? ch * f0 + ch * (1.0f - ch) * (1.0f - f0) : ch * pow(max(0.0f, 1.0f - ch), f0);

  // Hue
  float hue = calc_hue(r);

  // Hue extraction for primaries (RGB)
  float3 hp = float3(
    extract_hue_angle(hue, 2.0f, 1.0f, 0),
    extract_hue_angle(hue, 6.0f, 1.0f, 0),
    extract_hue_angle(hue, 4.0f, 1.0f, 0));
  hp = hp * ch;

  // Hue extraction for secondaries (CMY)
  float3 hs = float3(
    extract_hue_angle(hue, 5.0f, 1.0f, 0),
    extract_hue_angle(hue, 3.0f, 1.0f, 0),
    extract_hue_angle(hue, 1.0f, 1.0f, 0));
  hs = hs * ch;

  // Hue shift primaries
  r.x = r.x + sb*hp.z - sg*hp.y;
  r.y = r.y + sr*hp.x - sb*hp.z;
  r.z = r.z + sg*hp.y - sr*hp.x;
  
  // Hue shift secondaries
  r.x = r.x + sy*hs.z - sm*hs.y;
  r.y = r.y + sc*hs.x - sy*hs.z;
  r.z = r.z + sm*hs.y - sc*hs.x;

  // Hue extraction for custom
  float hc = extract_hue_angle(hue, cuh / 60.0f, cuw, 0);
  hc = hc * ch;
  
  // Calculate params for custom hue angle shift
  float h = cuh / 60.0f; // Convert degrees to 0-6 hue angle
  float s = scu * cuw; // Rotate only as much as the custom width
  // Calculate per-channel shift values based on hue angle
  float sc0 = h < 3.0f ? s - s*min(1, abs(h - 2.0f)) : s*min(1.0f, abs(h - 5.0f)) - s;
  float sc1 = h < 1.0f ? s - s*min(1.0f, abs(h)) : h < 5.0f ? s*min(1.0f, abs(h - 3.0f)) - s : s - s*min(1.0f, abs(h - 6.0f));
  float sc2 = h < 2.0f ? s*min(1.0f, abs(h - 1.0f)) - s : s - s*min(1.0f, abs(h - 4.0f));

  // Hue shift custom
  r.x = r.x + hc*(sc2-sc1);
  r.y = r.y + hc*(sc0-sc2);
  r.z = r.z + hc*(sc1-sc0);
  
  rgb = r * n;

  // Zone extract
  if (ze == 1) rgb = zone_extract(input, rgb, zp, zr);

  return rgb;
}

float3 open_drt_transform(
  float3 rgb,
  float Lp = 100.f,
  float gb = 0.12,
  float shadows = 1.f,
  float highlights = 1.f,
  float saturation = 1.f,
  float contrast = 1.f
  )
{

  // More visibility in shadows
  rgb = shd_con(rgb, 0.35f * lerp(4.f, -4.f, shadows / 2.f), 0.35f);

  // Adjust to ACES Shadows
  rgb += 0.001f;
  rgb = shd_con(rgb, -1.2f, 0.097f);

  // Adjust to ACES Highlights
  rgb = ex_high(rgb, -0.55f, -6.0f, 0.5f);
  rgb = ex_high(rgb, 0.5f, -3.0f, 0.5f);
  rgb = ex_high(rgb, 0.924f, -1.0f, 0.5f);
  rgb = ex_high(rgb, -0.15f, 2.68f, 0.19f);

  rgb = hl_con(rgb, highlights - 1.f, 203.f / 100.f);

  
  // **************************************************
  // Parameter Setup
  // --------------------------------------------------

  // Dechroma

  float dch = 0.4f;

  // Chroma contrast
  float chc_p = 1.2f; // amount of contrast
  float chc_m = 0.5f; // pivot of contrast curve

  // Tonescale parameters
  float c = 1.1f * contrast; // contrast
  float fl = 0.01f; // flare/glare compensation

  // Weights: controls the "vibrancy" of each channel, and influences all other aspects of the display-rendering.
  
  float3 weights = float3(
    0.001f, // 0.25
    0.359f, // 0.45
    0.11f   // 0.30
  );

  float vibrancy = weights.r + weights.g + weights.b;

  // Hue Shift RGB controls
  float3 hs = float3(
    0.3f,  // 0.3f
    1.4f,  // -0.1f
    -0.30f // -0.5f
  );
  
  /* Tonescale Parameters 
      ----------------------
    For the tonescale compression function, we use one inspired by the wisdom shared by Daniele Siragusano
    on the tonescale thread on acescentral: https://community.acescentral.com/t/output-transform-tone-scale/3498/224

    This is a variation which puts the power function _after_ the display-linear scale, which allows a simpler and exact
    solution for the intersection constraints. The resulting function is pretty much identical to Daniele's but simpler.
    Here is a desmos graph with the math. https://www.desmos.com/calculator/hglnae2ame

    And for more info on the derivation, see the "Michaelis-Menten Constrained" Tonescale Function here:
    https://colab.research.google.com/drive/1aEjQDPlPveWPvhNoEfK4vGH5Tet8y1EB#scrollTo=Fb_8dwycyhlQ

    For the user parameter space, we include the following creative controls:
    - Lp: display peak luminance. This sets the display device peak luminance and allows rendering for HDR.
    - contrast: This is a pivoted power function applied after the hyperbolic compress function, 
        which keeps middle grey and peak white the same but increases contrast in between.
    - flare: Applies a parabolic toe compression function after the hyperbolic compression function. 
        This compresses values near zero without clipping. Used for flare or glare compensation.
    - gb: Grey Boost. This parameter controls how many stops to boost middle grey per stop of peak luminance increase.

    Notes on the other non user-facing parameters:
    - (px, py): This is the peak luminance intersection constraint for the compression function.
        px is the input scene-linear x-intersection constraint. That is, the scene-linear input value 
        which is mapped to py through the compression function. By default this is set to 128 at Lp=100, and 256 at Lp=1000.
        Here is the regression calculation using a logarithmic function to match: https://www.desmos.com/calculator/chdqwettsj
    - (gx, gy): This is the middle grey intersection constraint for the compression function.
        Scene-linear input value gx is mapped to display-linear output gy through the function.
        Why is gy set to 0.11696 at Lp=100? This matches the position of middle grey through the Rec709 system.
        We use this value for consistency with the Arri and TCAM Rec.1886 display rendering transforms.
  */

  // input scene-linear peak x intercept
  float px = 256.0*log(Lp)/log(100.0) - 128.0f;
  // output display-linear peak y intercept
  float py = vibrancy * Lp/100.0f;
  // input scene-linear middle grey x intercept
  float gx = 0.18f;
  // output display-linear middle grey y intercept
  float gy = 11.696f/100.0f*(1.0f + gb*log(py)/log(2.0f));
  // s0 and s are input x scale for middle grey intersection constraint
  // m0 and m are output y scale for peak white intersection constraint
  float s0 = flare_invert(gy, fl);
  float m0 = flare_invert(py, fl);
  float ip = 1.0f/c;
  float s = (px*gx*(pow(m0, ip) - pow(s0, ip)))/(px*pow(s0, ip) - gx*pow(m0, ip));
  float m = pow(m0, ip)*(s + px)/px;



  /* Rendering Code ------------------------------------------ */

  // Convert into display gamut
  // rgb = mul(in_to_xyz, rgb);
  // rgb = mul(xyz_to_display, rgb);

  /* Take the the weighted sum of RGB. The weights
      scale the vector of each color channel, controlling the "vibrancy".
      We use this as a vector norm for separating color and intensity.
  */ 
  weights *= rgb; // multiply rgb by weights
  float lum = max(1e-8f, weights.x + weights.y + weights.z); // take the norm

  // RGB Ratios
  float3 rats = sdivf3f(rgb, lum);

  // Apply tonescale function to lum
  float ts;
  ts = tonescale(lum, m, s, c);
  ts = flare(ts, fl);

  // Normalize so peak luminance is at 1.0
  ts *= 100.0f/Lp;

  // Clamp ts to display peak
  ts = min(1.0f, ts);

  /* Gamut Compress ------------------------------------------ *
    Most of our data is now inside of the display gamut cube, but there may still be some gradient disruptions
    due to highly chromatic colors going outside of the display cube on the lower end and then being clipped
    whether implicitly or explicitly. To combat this, our last step is to do a soft clip or gamut compression.
    In RGB Ratios, 0,0,0 is the gamut boundary, and anything outside of gamut will have one or more negative 
    components. So to compress the gamut we use lift these negative values and compress them into a small range
    near 0. We use the "PowerP" hyperbolic compression function but it could just as well be anything.
  */
  rats.x = powerptoe(rats.x, 0.05f, -0.05f, 1.0f);
  rats.y = powerptoe(rats.y, 0.05f, -0.05f, 1.0f);
  rats.z = powerptoe(rats.z, 0.05f, -0.05f, 1.0f);

  /* Calculate RGB CMY hue angles from the input RGB.
    The classical way of calculating hue angle from RGB is something like this
    mx = max(r,g,b)
    mn = min(r,g,b)
    c = mx - mn
    hue = (c==0?0:r==mx?((g-b)/c+6)%6:g==mx?(b-r)/c+2:b==mx?(r-g)/c+4:0)
    With normalized chroma (distance from achromatic), being calculated like this
    chroma = (mx - mn)/mx
    chroma can also be calculated as 1 - mn/mx

    Here we split apart the calculation for hue and chroma so that we have access to RGB CMY
    individually without having to linear step extract the result again.

    To do this, we first calculate the "wide" hue angle: 
      wide hue RGB = (RGB - mn)/mx
      wide hue CMY = (mx - RGB)/mx
    and then "narrow down" the hue angle for each with channel subtraction (see narrow_hue_angles() function).
  */
  
  float mx = max(rats.x, max(rats.y, rats.z));
  float mn = min(rats.x, min(rats.y, rats.z));

  float3 rats_h = sdivf3f(rats - mn, mx);
  rats_h = narrow_hue_angles(rats_h);

  // Calculate "Chroma" (the normalized distance from achromatic).
  float rats_ch = 1.0f - sdivf(mn, mx);


  /* Chroma Value Compression ------------------------------------------ *
      RGB ratios may be greater than 1.0, which can result in discontinuities in highlight gradients.
      We compensate for this by normalizing the RGB Ratios so that max(r,g,b) does not exceed 1, and then mix
      the result. The factor for the mix is derived from tonescale * chroma, then taking only the top end of
      this with a compression function, so that we normalize only bright and saturated pixels.
  */

  // Normalization mix factor based on ccf * rgb chroma, smoothing transitions between r->g hue gradients
  float chf = ts*max(spowf(rats_h.x, 2.0f), max(spowf(rats_h.y, 2.0f), spowf(rats_h.z, 2.0f)));
  
  float chf_m = 0.25f;
  float chf_p = 0.65f;
  chf = 1.0f - spowf(spowf(chf/chf_m, 1.0f/chf_p)+1.0f, -chf_p);

  // Max of rgb ratios
  float rats_mx = max(rats.x, max(rats.y, rats.z));

  // Normalized rgb ratios
  float3 rats_n = sdivf3f(rats, rats_mx);

  // Mix based on chf
  rats = rats_n*chf + rats*(1.0f - chf);


  /* Chroma Compression ------------------------------------------ *
      Here we set up the chroma compression factor, used to lerp towards 1.0
      in RGB Ratios, thereby compressing color towards display peak.
      This factor is driven by ts, biased by a power function to control chroma compression amount `dch`.
  */
  // float ccf = 1.0f - pow(ts, 1.0f/dch);
  float ccf = 1.0f - (pow(ts, 1.0f/dch)*(1.0f-ts) + ts*ts);

  // Apply chroma compression to RGB Ratios
  rats = rats*ccf + 1.0f - ccf;


  /* Chroma Compression Hue Shift ------------------------------------------ *
      Since we compress chroma by lerping in a straight line towards 1.0 in rgb ratios, this can result in perceptual hue shifts
      due to the Abney effect. For example, pure blue compressed in a straight line towards achromatic appears to shift in hue towards purple.

      To combat this, and to add another important user control for image appearance, we add controls to curve the hue paths 
      as they move towards achromatic. We include only controls for primary colors: RGB. In my testing, it was of limited use to
      control hue paths for CMY.

      To accomplish this, we use the inverse of the chroma compression factor multiplied by the RGB hue angles as a factor
      for a lerp between the various rgb components.

      We don't include the toe chroma compression for this hue shift. It is mostly important for highlights.
  */
  float3 hsf = ccf*rats_h;
  
  // Apply hue shift to RGB Ratios
  float3 rats_hs = float3(rats.x + hsf.z*hs.z - hsf.y*hs.y, rats.y + hsf.x*hs.x - hsf.z*hs.z, rats.z + hsf.y*hs.y - hsf.x*hs.x);

  // Mix hue shifted RGB ratios by ts, so that we shift where highlights were chroma compressed plus a bit.
  rats = rats_hs*ts + rats*(1.0f - ts);


  /* Chroma Contrast
      Without this step, mid-range chroma in shadows and midtones looks too grey and dead.
      This is common with chromaticity-linear view transforms.
      In order to improve skin-tone rendering and overal "vibrance" of the image, which we
      are used to seeing with per-channel style view transforms, we boost mid-range chroma
      in shadows and midtones using a "chroma contrast" setup.
      
      Basically we take classical chroma (distance from achromatic), we take the compressed tonescale curve, 
      and we apply a contrast to the tonescale curve mixed by a parabolic center extraction of chroma, 
      so that we do not boost saturation at grey (increases noise), nor do we boost saturation of highly
      saturated colors which might already be near the edge of the gamut volume.
  */
  float chc_f = 4.0f*rats_ch*(1.0f - rats_ch);
  float chc_sa = min(2.0f, sdivf(lum, chc_m*spowf(sdivf(lum, chc_m), chc_p)*chc_f + lum*(1.0f - chc_f)));
  float chc_L = 0.23f*rats.x + 0.69f*rats.y + 0.08f*rats.z; // Roughly P3 weights, doesn't matter
  
  // Apply mid-range chroma contrast saturation boost
  rats = chc_L*(1.0f - chc_sa) + rats*chc_sa;

  // Apply tonescale to RGB Ratios
  rgb = rats*ts;

  // Clamp
  rgb = saturate(rgb);

  return rgb;
}