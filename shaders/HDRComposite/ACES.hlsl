#include "../math.hlsl"

#define ACES_PI            3.14159265359f


struct AcesParams {
	float3 Min;
	float3 Mid;
	float3 Max;
	float coefsLow[6];
	float coefsHigh[6];
};

static const float3x3 sRGB_2_AP0 = {
	0.4397010, 0.3829780, 0.1773350,
	0.0897923, 0.8134230, 0.0967616,
	0.0175440, 0.1115440, 0.8707040
};

static const float3x3 AP0_2_SRGB = {
	2.5214008886, -1.1339957494, -0.3875618568,
 -0.2762140616,  1.3725955663, -0.0962823557,
 -0.0153202001, -0.1529925618,  1.1683871996
};



static const float3x3 SRGB_2_XYZ_MAT =
{
	0.4124564, 0.3575761, 0.1804375,
	0.2126729, 0.7151522, 0.0721750,
	0.0193339, 0.1191920, 0.9503041,
};

static const float3x3 XYZ_2_AP0_MAT =
{
	 1.0498110175, 0.0000000000,-0.0000974845,
	-0.4959030231, 1.3733130458, 0.0982400361,
	 0.0000000000, 0.0000000000, 0.9912520182,
};

static const float3x3 AP1_2_SRGB =
{
	 1.7048586763, -0.6217160219, -0.0832993717,
	-0.1300768242,  1.1407357748, -0.0105598017,
	-0.0239640729, -0.1289755083,  1.1530140189
};

// mul( AP0_2_XYZ_MAT, XYZ_2_AP1_MAT );
static const float3x3 AP0_2_AP1_MAT = {
	 1.4514393161, -0.2365107469, -0.2149285693,
	-0.0765537734,  1.1762296998, -0.0996759264,
	 0.0083161484, -0.0060324498,  0.9977163014,
};

static const float3 AP1_RGB2Y = {
	0.2722287168, //AP1_2_XYZ_MAT[0][1],
	0.6740817658, //AP1_2_XYZ_MAT[1][1],
	0.0536895174, //AP1_2_XYZ_MAT[2][1]
};

static const float3x3 AP1_2_XYZ_MAT = {
	 0.6624541811, 0.1340042065, 0.1561876870,
	 0.2722287168, 0.6740817658, 0.0536895174,
	-0.0055746495, 0.0040607335, 1.0103391003
};

static const float3x3 D60_2_D65_CAT = {
	 0.98722400, -0.00611327, 0.0159533,
	-0.00759836,  1.00186000, 0.0053302,
	 0.00307257, -0.00509595, 1.0816800
};

static const float3x3 D65_2_D60_CAT =
{
	 1.01303,    0.00610531, -0.014971,
	 0.00769823, 0.998165,   -0.00503203,
	-0.00284131, 0.00468516,  0.924507,
};

static const float3x3 XYZ_2_sRGB_MAT =
{
	 3.2409699419, -1.5373831776, -0.4986107603,
	-0.9692436363,  1.8759675015,  0.0415550574,
	 0.0556300797, -0.2039769589,  1.0569715142,
};

static const half3x3 AP1_2_AP0_MAT = {
	0.6954522414, 0.1406786965, 0.1638690622,
	0.0447945634, 0.8596711185, 0.0955343182,
	-0.0055258826, 0.0040252103, 1.0015006723
};

static const float3x3 BlueCorrect =
	{
		0.9404372683, -0.0183068787, 0.0778696104,
		0.0083786969,  0.8286599939, 0.1629613092,
		0.0005471261, -0.0008833746, 1.0003362486
	};
static const float3x3 BlueCorrectInv =
{
	1.06318,     0.0233956, -0.0865726,
	-0.0106337,   1.20632,   -0.19569,
	-0.000590887, 0.00105248, 0.999538
};

static const float3x3 BlueCorrectAP1    = mul( AP0_2_AP1_MAT, mul( BlueCorrect, AP1_2_AP0_MAT ) );

static const float3x3 BlueCorrectInvAP1 = mul( AP0_2_AP1_MAT, mul( BlueCorrectInv, AP1_2_AP0_MAT ) );

static const half3x3 M = {
	 0.5, -1.0, 0.5,
	-1.0,  1.0, 0.0,
	 0.5,  0.5, 0.0
};

static const half3x3 RRT_SAT_MAT = {
	0.9708890, 0.0269633, 0.00214758,
	0.0108892, 0.9869630, 0.00214758,
	0.0108892, 0.0269633, 0.96214800
};

static const half3x3 ODT_SAT_MAT = {
	0.949056, 0.0471857, 0.00375827,
	0.019056, 0.9771860, 0.00375827,
	0.019056, 0.0471857, 0.93375800
};

static const float MIN_STOP_SDR = -6.5;
static const float MAX_STOP_SDR = 6.5;

static const float MIN_STOP_RRT = -15.0;
static const float MAX_STOP_RRT = 18.0;

static const float MIN_LUM_SDR = 0.02;
static const float MAX_LUM_SDR = 48.0;

static const float MIN_LUM_RRT = 0.0001;
static const float MAX_LUM_RRT = 10000.0;

static const float2x2 MIN_LUM_TABLE = {
	log10(MIN_LUM_RRT), MIN_STOP_RRT,
	log10(MIN_LUM_SDR), MIN_STOP_SDR
};

static const float2x2 MAX_LUM_TABLE = {
	log10(MAX_LUM_SDR), MAX_STOP_SDR,
	log10(MAX_LUM_RRT), MAX_STOP_RRT
};

static const float2x2 BENDS_LOW_TABLE = { 
	MIN_STOP_RRT, 0.18,
	MIN_STOP_SDR, 0.35
};

static const float2x2 BENDS_HIGH_TABLE = {
	MAX_STOP_SDR, 0.89,
	MAX_STOP_RRT, 0.90
};

// Sigmoid function in the range 0 to 1 spanning -2 to +2.
float sigmoid_shaper(float x) {
	float t = max( 1 - abs( 0.5 * x ), 0 );
	float y = 1 + sign(x) * (1 - t*t);
	return 0.5 * y;
}

float rgb_2_saturation( float3 rgb ) {
	float minrgb = min( min(rgb.r, rgb.g ), rgb.b );
	float maxrgb = max( max(rgb.r, rgb.g ), rgb.b );
	return ( max( maxrgb, 1e-10 ) - max( minrgb, 1e-10 ) ) / max( maxrgb, 1e-2 );
}

float glow_fwd( float ycIn, float glowGainIn, float glowMid) {
	float glowGainOut;

	if (ycIn <= 2./3. * glowMid) {
		glowGainOut = glowGainIn;
	} else if ( ycIn >= 2 * glowMid) {
		glowGainOut = 0;
	} else {
		glowGainOut = glowGainIn * (glowMid / ycIn - 0.5);
	}

	return glowGainOut;
}

// Transformations from RGB to other color representations
float rgb_2_hue( float3 rgb ) {
	// Returns a geometric hue angle in degrees (0-360) based on RGB values.
	// For neutral colors, hue is undefined and the function will return a quiet NaN value.
	float hue;
	if (rgb.x == rgb.y && rgb.y == rgb.z) {
		hue = 0.0; // RGB triplets where RGB are equal have an undefined hue
	} else {
		hue = (180.0f / ACES_PI) * atan2(sqrt(3.0f) * (rgb.y - rgb.z), 2.0f * rgb.x - rgb.y - rgb.z);
	}

	if (hue < 0.0f) {
		hue = hue + 360.0f;
	}

	return hue;
}

float rgb_2_yc( float3 rgb, float ycRadiusWeight = 1.75) {
	// Converts RGB to a luminance proxy, here called YC
	// YC is ~ Y + K * Chroma
	// Constant YC is a cone-shaped surface in RGB space, with the tip on the 
	// neutral axis, towards white.
	// YC is normalized: RGB 1 1 1 maps to YC = 1
	//
	// ycRadiusWeight defaults to 1.75, although can be overridden in function 
	// call to rgb_2_yc
	// ycRadiusWeight = 1 -> YC for pure cyan, magenta, yellow == YC for neutral 
	// of same value
	// ycRadiusWeight = 2 -> YC for pure red, green, blue  == YC for  neutral of 
	// same value.

	float r = rgb[0]; 
	float g = rgb[1]; 
	float b = rgb[2];

	float chroma = sqrt(b*(b-g)+g*(g-r)+r*(r-b));

	return ( b + g + r + ycRadiusWeight * chroma) / 3.;
}


float center_hue( float hue, float centerH) {
	float hueCentered = hue - centerH;
	if (hueCentered < -180.)
		hueCentered += 360;
	else if (hueCentered > 180.)
		hueCentered -= 360;
	return hueCentered;
}


// Transformations between CIE XYZ tristimulus values and CIE x,y 
// chromaticity coordinates
float3 XYZ_2_xyY( float3 XYZ ) {
	float3 xyY;
	float divisor = (XYZ[0] + XYZ[1] + XYZ[2]);
	if (divisor == 0.) divisor = 1e-10;
	xyY[0] = XYZ[0] / divisor;
	xyY[1] = XYZ[1] / divisor;
	xyY[2] = XYZ[1];

	return xyY;
}

float3 xyY_2_XYZ( float3 xyY ) {
	float3 XYZ;
	XYZ[0] = xyY[0] * xyY[2] / max( xyY[1], 1e-10);
	XYZ[1] = xyY[2];
	XYZ[2] = (1.0 - xyY[0] - xyY[1]) * xyY[2] / max( xyY[1], 1e-10);

	return XYZ;
}

float interpolate1D(float2x2 table, float p) {
	if (p < table[0].x) return table[0].y;
	if (p >= table[1].x) return table[1].y;
	// p = clamp(p, table[0].x, table[1].x);
	float s = (p - table[0].x) / (table[1].x - table[0].x);
	return table[0].y * ( 1 - s ) + table[1].y * s;
}

float3 Y_2_linCV( float3 Y, float Ymax, float Ymin) {
	return (Y - Ymin) / (Ymax - Ymin);
}

float3 linCV_2_Y( float3 linCV, float Ymax, float Ymin) {
  return linCV * (Ymax - Ymin) + Ymin;
}

float lookup_ACESmin(float minLumLog10)
{
	return 0.18 * exp2(interpolate1D(MIN_LUM_TABLE, minLumLog10));
}

float lookup_ACESmax( float maxLumLog10 )
{
	return 0.18 * exp2(interpolate1D( MAX_LUM_TABLE, maxLumLog10));
}

AcesParams init_aces_params(float minLum, float maxLum) {
	float minLumLog10 = log10(minLum);
	float maxLumLog10 = log10(maxLum);
	float acesMin = lookup_ACESmin(minLumLog10);
	float acesMax = lookup_ACESmax(maxLumLog10);
	// float3 MIN_PT = float3(lookup_ACESmin(minLum), minLum, 0.0);
	float3 MID_PT = float3(0.18, 4.8, 1.55);
	// float3 MAX_PT = float3(lookup_ACESmax(maxLum), maxLum, 0.0);
	float coefsLow[5];
	float coefsHigh[5];

	float2 logMin = float2(log10(acesMin), minLumLog10);
	float2 logMid = float2(log10(MID_PT.xy));
	float2 logMax = float2(log10(acesMax), maxLumLog10);
	
	float knotIncLow = (logMid.x - logMin.x) / 3.;
	// float halfKnotInc = (logMid.x - logMin.x) / 6.;

	// Determine two lowest coefficients (straddling minPt)
	// coefsLow[0] = (MIN_PT.z * (logMin.x- 0.5 * knotIncLow)) + ( logMin.y - MIN_PT.z * logMin.x);
	// coefsLow[1] = (MIN_PT.z * (logMin.x+ 0.5 * knotIncLow)) + ( logMin.y - MIN_PT.z * logMin.x);
	// NOTE: if slope=0, then the above becomes just
	coefsLow[0] = logMin.y;
	coefsLow[1] = coefsLow[0];
	// leaving it as a variable for now in case we decide we need non-zero slope extensions

	// Determine two highest coefficients (straddling midPt)
	float minCoef = (logMid.y - MID_PT.z * logMid.x);
	coefsLow[3] = (MID_PT.z * (logMid.x-0.5*knotIncLow)) + (logMid.y - MID_PT.z * logMid.x);
	coefsLow[4] = (MID_PT.z * (logMid.x+0.5*knotIncLow)) + (logMid.y - MID_PT.z * logMid.x);

	// Middle coefficient (which defines the "sharpness of the bend") is linearly interpolated
	float pctLow = interpolate1D( BENDS_LOW_TABLE, log2(acesMin/0.18));
	coefsLow[2] = logMin.y + pctLow*(logMid.y-logMin.y);
	
	float knotIncHigh = (logMax.x - logMid.x) / 3.0f;
	// float halfKnotInc = (logMax.x - logMid.x) / 6.;

	// Determine two lowest coefficients (straddling midPt)
	// float minCoef = ( logMid.y - MID_PT.z * logMid.x);
	coefsHigh[0] = (MID_PT.z * (logMid.x-0.5*knotIncHigh)) + minCoef;
	coefsHigh[1] = (MID_PT.z * (logMid.x+0.5*knotIncHigh)) + minCoef;

	// Determine two highest coefficients (straddling maxPt)
	// coefsHigh[3] = (MAX_PT.z * (logMax.x-0.5*knotIncHigh)) + ( logMax.y - MAX_PT.z * logMax.x);
	// coefsHigh[4] = (MAX_PT.z * (logMax.x+0.5*knotIncHigh)) + ( logMax.y - MAX_PT.z * logMax.x);
	// NOTE: if slope=0, then the above becomes just
		coefsHigh[3] = logMax.y;
		coefsHigh[4] = coefsHigh[3];
	// leaving it as a variable for now in case we decide we need non-zero slope extensions

	// Middle coefficient (which defines the "sharpness of the bend") is linearly interpolated

	float pctHigh = interpolate1D( BENDS_HIGH_TABLE, log2(acesMax/0.18));
	coefsHigh[2] = logMid.y + pctHigh*(logMax.y-logMid.y);


	AcesParams P = {
		float3(logMin.x, logMin.y, 0),
		float3(logMid.x, logMid.y, MID_PT.z),
		float3(logMax.x, logMax.y, 0),
		{coefsLow[0], coefsLow[1], coefsLow[2], coefsLow[3], coefsLow[4], coefsLow[4]},
		{coefsHigh[0], coefsHigh[1], coefsHigh[2], coefsHigh[3], coefsHigh[4], coefsHigh[4]}
	};

	return P;
}



float computeGraphY(float m, float x, float b) {
	return m * x + b;
}

float SSTS(float x, AcesParams C) {
	const int N_KNOTS_LOW = 4;
	const int N_KNOTS_HIGH = 4;

	// Check for negatives or zero before taking the log. If negative or zero,
	// set to HALF_MIN.
	float logx = log10( max(x, FLT_MIN));

	float logy;

	if (logx > C.Max.x) {
		// Above max breakpoint (overshoot)
		// If MAX_PT slope is 0, this is just a straight line and always returns
		// maxLum
		// y = mx+b
		// logy = computeGraphY(C.Max.z, logx, (C.Max.y) - (C.Max.z * (C.Max.x)));
		logy = C.Max.y;
	} else if (logx >= C.Mid.x) {
		// Part of Midtones area (Must have slope)
		float knot_coord = (N_KNOTS_HIGH-1) * (logx-C.Mid.x)/(C.Max.x-C.Mid.x);
		int j = knot_coord;
		float t = knot_coord - j;

		float3 cf = float3(C.coefsHigh[j], C.coefsHigh[j + 1], C.coefsHigh[j + 2]);

		float3 monomials = float3(t * t, t, 1.0);
		logy = dot(monomials, mul(M, cf));
	} else if (logx > C.Min.x) {
		float knot_coord = (N_KNOTS_LOW-1) * (logx-C.Min.x)/(C.Mid.x-C.Min.x);
		int j = knot_coord;
		float t = knot_coord - j;

		float3 cf = float3(C.coefsLow[j], C.coefsLow[j + 1], C.coefsLow[j + 2]);

		float3 monomials = float3(t * t, t, 1.0);
		logy = dot(monomials, mul(M, cf));
	} else { //(logx <= (C.Min.x))
		// Below min breakpoint (undershoot)
		// logy = computeGraphY(C.Min.z, logx, ((C.Min.y) - C.Min.z * (C.Min.x)));
		logy = C.Min.y;
	}

	return pow(10.0, logy);
}

static float LIM_CYAN =  1.147f;
static float LIM_MAGENTA = 1.264f;
static float LIM_YELLOW = 1.312f;
static float THR_CYAN = 0.815f;
static float THR_MAGENTA = 0.803f;
static float THR_YELLOW = 0.880f;
static float PWR = 1.2f;

float aces_gamut_compress_channel(float dist, float lim, float thr, float pwr)
{
    float comprDist;
    float scl;
    float nd;
    float p;

    if (dist < thr) {
        comprDist = dist; // No compression below threshold
    }
    else {
        // Calculate scale factor for y = 1 intersect
        scl = (lim - thr) / pow(pow((1.0 - thr) / (lim - thr), -pwr) - 1.0, 1.0 / pwr);

        // Normalize distance outside threshold by scale factor
        nd = (dist - thr) / scl;
        p = pow(nd, pwr);

        comprDist = thr + scl * nd / (pow(1.0 + p, 1.0 / pwr)); // Compress
    }

    return comprDist;
}

float3 aces_gamut_compress(float3 linAP1)
{
	
    // Achromatic axis
    float ach = max(linAP1.r, max(linAP1.g, linAP1.b));
		float absAch = abs(ach);
    // Distance from the achromatic axis for each color component aka inverse RGB ratios
    float3 dist = ach ? (ach - linAP1) / absAch : 0;

    // Compress distance with parameterized shaper function
    float3 comprDist = float3(
        aces_gamut_compress_channel(dist.r, LIM_CYAN, THR_CYAN, PWR),
        aces_gamut_compress_channel(dist.g, LIM_MAGENTA, THR_MAGENTA, PWR),
        aces_gamut_compress_channel(dist.b, LIM_YELLOW, THR_YELLOW, PWR)
		);

    // Recalculate RGB from compressed distance and achromatic
    float3 comprLinAP1 = ach - comprDist * absAch;

    return comprLinAP1;
}


float3 aces_rrt(float3 rgb) {
	float3 aces = mul(sRGB_2_AP0, rgb);
		// --- Glow module --- //
	// "Glow" module constants
	const float RRT_GLOW_GAIN = 0.05;
	const float RRT_GLOW_MID = 0.08;
	float saturation = rgb_2_saturation( aces);
	float ycIn = rgb_2_yc( aces);
	float s = sigmoid_shaper( (saturation - 0.4) / 0.2);
	float addedGlow = 1.0 + glow_fwd( ycIn, RRT_GLOW_GAIN * s, RRT_GLOW_MID);
	aces *= addedGlow;

	// --- Red modifier --- //
	// Red modifier constants
	const float RRT_RED_SCALE = 0.82;
	const float RRT_RED_PIVOT = 0.03;
	const float RRT_RED_HUE = 0.;
	const float RRT_RED_WIDTH = 135.;
	float hue = rgb_2_hue( aces);
	float centeredHue = center_hue( hue, RRT_RED_HUE);
	float hueWeight;
	{
		//hueWeight = cubic_basis_shaper(centeredHue, RRT_RED_WIDTH);
		hueWeight = smoothstep(0.0, 1.0, 1.0 - abs(2.0 * centeredHue / RRT_RED_WIDTH));
		hueWeight *= hueWeight;
	}

	aces.r += hueWeight * saturation * (RRT_RED_PIVOT - aces.r) * (1. - RRT_RED_SCALE);

	// --- ACES to RGB rendering space --- //
	aces = clamp(aces, 0,  65504.0);
	float3 rgbPre = mul(AP0_2_AP1_MAT, aces);
	rgbPre = clamp(rgbPre, 0, 65504.0);

	// --- Global desaturation --- //
	rgbPre = mul( RRT_SAT_MAT, rgbPre);

	rgbPre = lerp( rgbPre, mul( BlueCorrectAP1, rgbPre ), 0.6f );
	rgbPre = aces_gamut_compress(rgbPre);
	
	return rgbPre;
}

float3 aces_odt_tone_map(float3 rgbPre, float minY, float maxY) {
	float3 rgbPost;
	// Aces-dev has more expensive version
	AcesParams PARAMS = init_aces_params(minY, maxY);
	rgbPost.x = SSTS(rgbPre.x, PARAMS);
	rgbPost.y = SSTS(rgbPre.y, PARAMS);
	rgbPost.z = SSTS(rgbPre.z, PARAMS);

	// Not clamping may produce pink dots
	return max(0, Y_2_linCV( rgbPost, maxY, minY));
}

float3 aces_odt(float3 rgbPre, float minY, float maxY, bool darkToDim = false) {

	float3 scaled = aces_odt_tone_map(rgbPre, minY, maxY);
	
	scaled = lerp( scaled, mul( BlueCorrectInvAP1, scaled ), 0.6f );
	
	float3 XYZ = mul( AP1_2_XYZ_MAT, scaled );
	XYZ = mul( D60_2_D65_CAT, XYZ );

	if (darkToDim) {
		float3 xyY = XYZ_2_xyY(XYZ);
		xyY.z = clamp(xyY.z, 0.0, 65504.0);
		xyY.z = pow(xyY.z, 0.9811); // DIM_SURROUND_GAMMA
		XYZ = xyY_2_XYZ(xyY);
	}

	float3 linearCV = mul( XYZ_2_sRGB_MAT, XYZ );

	// This step is missing in ACES's OutputTransform but is present on ODTs
	linearCV = mul(ODT_SAT_MAT, linearCV);
	return linearCV;
}


float3 aces_rrt_odt(float3 srgb, float minY, float maxY, bool darkToDim = false) {
	return aces_odt(
		aces_rrt(srgb),
		minY,
		maxY,
		darkToDim
	);
}