#define ACES_PI            3.14159265359f

struct TsPoint {
	float x;
	float y;
	float slope;
};

struct TsParams {
	TsPoint Min;
	TsPoint Mid;
	TsPoint Max;
	float coefsLow[6];
	float coefsHigh[6];
};

#define HALF_MIN 6.10352e-5f

static const float3x3 sRGB_2_AP0 = {
	0.4397010, 0.3829780, 0.1773350,
	0.0897923, 0.8134230, 0.0967616,
	0.0175440, 0.1115440, 0.8707040
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

static const float3x3 XYZ_2_sRGB_MAT =
{
	 3.2409699419, -1.5373831776, -0.4986107603,
	-0.9692436363,  1.8759675015,  0.0415550574,
	 0.0556300797, -0.2039769589,  1.0569715142,
};

static const half3x3 M = {
	 0.5, -1.0, 0.5,
	-1.0,  1.0, 0.0,
	 0.5,  0.5, 0.0
};

static const float MIN_STOP_SDR = -6.5;
static const float MAX_STOP_SDR = 6.5;

static const float MIN_STOP_RRT = -15.0;
static const float MAX_STOP_RRT = 18.0;

static const float MIN_LUM_SDR = 0.02;
static const float MAX_LUM_SDR = 48.0;

static const float MIN_LUM_RRT = 0.0001;
static const float MAX_LUM_RRT = 10000.0;

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
	p = clamp(p, table[0].x, table[1].x);
	float s = (p - table[0].x) / (table[1].x - table[0].x);
	return table[0].y * ( 1 - s ) + table[1].y * s;
}

float3 Y_2_linCV( float3 Y, float Ymax, float Ymin) {
	return (Y - Ymin) / (Ymax - Ymin);
}

float3 linCV_2_Y( float3 linCV, float Ymax, float Ymin)
{
  return linCV * (Ymax - Ymin) + Ymin;
}

float3 RRTSweeteners(float3 aces) {
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
	rgbPre = clamp( rgbPre, 0,  65504.0);

	// --- Global desaturation --- //
	// Desaturation contants
	const float RRT_SAT_FACTOR = 0.96;
	rgbPre = lerp(dot(rgbPre, AP1_RGB2Y).xxx, rgbPre, RRT_SAT_FACTOR.xxx);
	return rgbPre;
}

float lookup_ACESmin(float minLum)
{
	const float2x2 minTable = {
		log10(MIN_LUM_RRT), MIN_STOP_RRT,
		log10(MIN_LUM_SDR), MIN_STOP_SDR
	};

	return 0.18 * exp2(interpolate1D(minTable, log10(minLum)));
}

float lookup_ACESmax( float maxLum )
{
	const float2x2 maxTable = {
		log10(MAX_LUM_SDR), MAX_STOP_SDR,
		log10(MAX_LUM_RRT), MAX_STOP_RRT
	};

	return 0.18 *exp2(interpolate1D( maxTable, log10( maxLum)));
}

void init_coefsLow(
	TsPoint TsPointLow,
	TsPoint TsPointMid,
	out float coefsLow[5]
)
{
	float knotIncLow = (log10(TsPointMid.x) - log10(TsPointLow.x)) / 3.;
	// float halfKnotInc = (log10(TsPointMid.x) - log10(TsPointLow.x)) / 6.;

	// Determine two lowest coefficients (straddling minPt)
	// coefsLow[0] = (TsPointLow.slope * (log10(TsPointLow.x)- 0.5 * knotIncLow)) + ( log10(TsPointLow.y) - TsPointLow.slope * log10(TsPointLow.x));
	// coefsLow[1] = (TsPointLow.slope * (log10(TsPointLow.x)+ 0.5 * knotIncLow)) + ( log10(TsPointLow.y) - TsPointLow.slope * log10(TsPointLow.x));
	// NOTE: if slope=0, then the above becomes just
		coefsLow[0] = log10(TsPointLow.y);
		coefsLow[1] = coefsLow[0];
	// leaving it as a variable for now in case we decide we need non-zero slope extensions

	// Determine two highest coefficients (straddling midPt)
	coefsLow[3] = (TsPointMid.slope * (log10(TsPointMid.x)-0.5*knotIncLow)) + ( log10(TsPointMid.y) - TsPointMid.slope * log10(TsPointMid.x));
	coefsLow[4] = (TsPointMid.slope * (log10(TsPointMid.x)+0.5*knotIncLow)) + ( log10(TsPointMid.y) - TsPointMid.slope * log10(TsPointMid.x));

	// Middle coefficient (which defines the "sharpness of the bend") is linearly interpolated
	float2x2 bendsLow = { 
		MIN_STOP_RRT, 0.18,
		MIN_STOP_SDR, 0.35
	};
	float pctLow = interpolate1D( bendsLow, log2(TsPointLow.x/0.18));
	coefsLow[2] = log10(TsPointLow.y) + pctLow*(log10(TsPointMid.y)-log10(TsPointLow.y));
}

void init_coefsHigh(TsPoint TsPointMid, TsPoint TsPointMax, out float coefsHigh[5]) {
	float knotIncHigh = (log10(TsPointMax.x) - log10(TsPointMid.x)) / 3.0f;
	// float halfKnotInc = (log10(TsPointMax.x) - log10(TsPointMid.x)) / 6.;

	// Determine two lowest coefficients (straddling midPt)
	coefsHigh[0] = (TsPointMid.slope * (log10(TsPointMid.x)-0.5*knotIncHigh)) + ( log10(TsPointMid.y) - TsPointMid.slope * log10(TsPointMid.x));
	coefsHigh[1] = (TsPointMid.slope * (log10(TsPointMid.x)+0.5*knotIncHigh)) + ( log10(TsPointMid.y) - TsPointMid.slope * log10(TsPointMid.x));

	// Determine two highest coefficients (straddling maxPt)
	// coefsHigh[3] = (TsPointMax.slope * (log10(TsPointMax.x)-0.5*knotIncHigh)) + ( log10(TsPointMax.y) - TsPointMax.slope * log10(TsPointMax.x));
	// coefsHigh[4] = (TsPointMax.slope * (log10(TsPointMax.x)+0.5*knotIncHigh)) + ( log10(TsPointMax.y) - TsPointMax.slope * log10(TsPointMax.x));
	// NOTE: if slope=0, then the above becomes just
		coefsHigh[3] = log10(TsPointMax.y);
		coefsHigh[4] = coefsHigh[3];
	// leaving it as a variable for now in case we decide we need non-zero slope extensions

	// Middle coefficient (which defines the "sharpness of the bend") is linearly interpolated
	float2x2 bendsHigh = {
		MAX_STOP_SDR, 0.89,
		MAX_STOP_RRT, 0.90
	};
	float pctHigh = interpolate1D( bendsHigh, log2(TsPointMax.x/0.18));
	coefsHigh[2] = log10(TsPointMid.y) + pctHigh*(log10(TsPointMax.y)-log10(TsPointMid.y));
}

float shift(float input, float expShift) {
	return exp2(log2(input) - expShift);
}

TsParams init_TsParams(float minLum, float maxLum, float expShift = 0)
{
	TsPoint MIN_PT = { lookup_ACESmin(minLum), minLum, 0.0};
	TsPoint MID_PT = { 0.18, 4.8, 1.55};
	TsPoint MAX_PT = { lookup_ACESmax(maxLum), maxLum, 0.0};
	float cLow[5];
	float cHigh[5];
	init_coefsLow( MIN_PT, MID_PT, cLow);
	init_coefsHigh( MID_PT, MAX_PT, cHigh);
	MIN_PT.x = shift(lookup_ACESmin(minLum),expShift);
	MID_PT.x = shift(0.18,expShift);
	MAX_PT.x = shift(lookup_ACESmax(maxLum),expShift);

	TsParams P = {
		{MIN_PT.x, MIN_PT.y, MIN_PT.slope},
		{MID_PT.x, MID_PT.y, MID_PT.slope},
		{MAX_PT.x, MAX_PT.y, MAX_PT.slope},
		{cLow[0], cLow[1], cLow[2], cLow[3], cLow[4], cLow[4]},
		{cHigh[0], cHigh[1], cHigh[2], cHigh[3], cHigh[4], cHigh[4]}
	};

	return P;
}



float computeGraphY(float m, float x, float b) {
	return m * x + b;
}

float SSTS(float x, TsParams C) {
	const int N_KNOTS_LOW = 4;
	const int N_KNOTS_HIGH = 4;

	// Check for negatives or zero before taking the log. If negative or zero,
	// set to HALF_MIN.
	float logx = log10( max(x, HALF_MIN));

	float logy;

	if (logx > log10(C.Max.x)) {
		// Above max breakpoint (overshoot)
		// If MAX_PT slope is 0, this is just a straight line and always returns
		// maxLum
		// y = mx+b
		// logy = computeGraphY(C.Max.slope, logx, log10(C.Max.y) - (C.Max.slope * log10(C.Max.x)));
		logy = log10(C.Max.y);
	} else if (logx >= log10(C.Mid.x)) {
		// Part of Midtones area (Must have slope)
		float knot_coord = (N_KNOTS_HIGH-1) * (logx-log10(C.Mid.x))/(log10(C.Max.x)-log10(C.Mid.x));
		int j = knot_coord;
		float t = knot_coord - j;

		float3 cf = { C.coefsHigh[j], C.coefsHigh[j + 1], C.coefsHigh[j + 2]};

		float3 monomials = { t * t, t, 1.0 };
		logy = dot( monomials, mul(M, cf));
	} else if (logx > log10(C.Min.x)) {
		float knot_coord = (N_KNOTS_LOW-1) * (logx-log10(C.Min.x))/(log10(C.Mid.x)-log10(C.Min.x));
		int j = knot_coord;
		float t = knot_coord - j;

		float3 cf = {C.coefsLow[ j], C.coefsLow[j + 1], C.coefsLow[ j + 2]};

		float3 monomials = { t * t, t, 1.0 };
		logy = dot(monomials, mul(M, cf));
	} else { //(logx <= log10(C.Min.x))
		// Below min breakpoint (undershoot)
		// logy = computeGraphY(C.Min.slope, logx, (log10(C.Min.y) - C.Min.slope * log10(C.Min.x)));
		logy = log10(C.Min.y);
	}

	return pow(10.0, logy);
}

float3 srgb_to_aces(float3 x) {
  return mul(sRGB_2_AP0, x);
}

static const half DIM_SURROUND_GAMMA = 0.9811;

float3 darkToDim(float3 XYZ) {
	float3 xyY = XYZ_2_xyY(XYZ);
	xyY.z = clamp(xyY.z, 0.0, 65504.0);
	xyY.z = pow(xyY.z, DIM_SURROUND_GAMMA);
	return xyY_2_XYZ(xyY);
}


float3 aces_rrt(float3 rgb) {
	float3 aces = srgb_to_aces(rgb);
	// RRT sweeteners
	return RRTSweeteners(aces);
}

float3 aces_odt(float3 rgbPre, float minY, float maxY, float expShift = 0) {

	float3 rgbPost;

	// Aces-dev has more expensive version
	TsParams PARAMS = init_TsParams(minY / 48.0f , 48.0f, expShift);
	rgbPost.x = SSTS(rgbPre.x, PARAMS);
	rgbPost.y = SSTS(rgbPre.y, PARAMS);
	rgbPost.z = SSTS(rgbPre.z, PARAMS);

	float3 scaled = Y_2_linCV( rgbPost, 48.0f, minY / 48.0f);
	
	// Convert to display primary encoding
	// Rendering space RGB to XYZ
	float3 XYZ = mul( AP1_2_XYZ_MAT, scaled );
	
	// This was already done with RRT sweeteners??
	// Apply desaturation to compensate for luminance difference
	// const float ODT_SAT_FACTOR = 0.93;
	// linearCV = lerp( dot( linearCV, AP1_RGB2Y ), linearCV, ODT_SAT_FACTOR );

	XYZ = mul( D60_2_D65_CAT, XYZ );

	float3 linearCV = mul( XYZ_2_sRGB_MAT, XYZ );
	linearCV = lerp(minY / 80.f, maxY / 80.f, linearCV);
	return linearCV;
}

