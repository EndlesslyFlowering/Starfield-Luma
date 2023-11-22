#pragma once

//HDRComposite start
struct ResolutionBlock
{
	float2 f2_0;
	float2 f2_1;
	float2 f2_2;
	float2 f2_3;
	int4   i4_0;
	float2 f2_4;
	float2 f2_5;
	float2 f2_6;
	float2 f2_7;
	float2 f2_8;
	int2   i2_0;
	int4   i4_1;
	float  f_0;
	int    i_0;
	int    i_1;
	int    i_2;
};

struct CameraBlock
{
	float3   f3_0;
	int      i_1;
	float4x4 f4x4_0;
	float4x4 f4x4_1;
	float4x4 f4x4_2;
	float4x4 f4x4_3;
	float4x4 f4x4_4;
	float4x4 f4x4_5;
	float3   f3_1;
	int      i_0;
	float4x4 f4x4_6;
	float4x4 f4x4_7;
	float4x4 f4x4_8;
	float4   f4_0;
	float4   f4_1;
	float4   f4_2;
	float4   f4_3;
	float2   f2_0;
	float    f_0;
	float    f_1;
};

struct CameraBlockArray
{
	CameraBlock     cb0;
	CameraBlock     cb1;
	CameraBlock     cb2;
	ResolutionBlock rb0;
	ResolutionBlock rb1;
	ResolutionBlock rb2;
	ResolutionBlock rb3;
	ResolutionBlock rb4;
};

struct SPerSceneConstants
{
	CameraBlockArray cba;
//    WindData;
//    CameraExposureData;
//    GlobalLightData;
//    GlobalShadowData;
//    ReflectionProbeDescData;
//    ReflectionProbeExposureData;
//    SIndirectLightingData;
//    ProbeRenderData;
//    PlanetConstantsData;
//    float pcs0;
//    int   pcs1;
//    int   pcs2;
//    float pcs3;
//    TiledBinning_idTech7FrameData;
//    float pcs4;
//    float pcs5;
//    float pcs6;
//    float pcs7;
//    float pcs8;
//    float pcs9;
//    float pcs10;
//    float pcs11;
//    float pcs12;
//    int   pcs13;
//    int   pcs14;
//    int   pcs15;
//    HairConstantData;
//    FogParams;
//    VolumetricLightingApplyParameters;
//    PrecomputeTransmittanceParameters;
//    HeightfieldData;
//    MomentBasedOITSettings;
//    TiledLightingDebug;
//    GPUDebugGeometrySettings;
//    TonemappingParams;
//    EffectsAlphaThresholdParams;
};

struct TonemappingParams
{
	float AcesParam0;
	float AcesParam1;
	float HableParam0;
	float HableParam1;
	float HableParam2;
	float HableParam3;
	float HableParam4;
	int   param7; //unused
};

struct PushConstantWrapper_HDRComposite
{
	uint  HdrCmpDatIndex; //index for HDRCompositeData
	uint  Tmo; //tone mapping operator
	float BloomMultiplier;
};

struct UserOptions {
	float fUserContrast;  // _23_m0[2].x [0-3]
	uint uHDRSupported;   // _23_m0[2].y [0|1]
	float fHDRBrightness; // _23_m0[2].z [0-1]
	float fUserUnknown1;  // _23_m0[2].w [3.5?]
	int2 u3;              // _23_m0[3].xy
	int u4;               // _23_m0[3].z
	int u5;               // _23_m0[3].w
	float u6;             // _23_m0[4].x
	int u7;               // _23_m0[4].y
	int u8;               // _23_m0[4].z
	int u9;               // _23_m0[4].w
	int u10;              // _23_m0[5].x
	int u11;              // _23_m0[5].y
	int u12;              // _23_m0[5].z
	int u13;              // _23_m0[5].w
}; // float4[4]
struct FrameData {
	int u1;          // _23_m0[0].x
	int u2;          // _23_m0[0].y
	float2 u3;       // _23_m0[0].zw
	float u4;        // _23_m0[1].x
	float u5;        // _23_m0[1].y
	float u6;        // _23_m0[1].z
	float Gamma;     // _23_m0[1].w
	UserOptions UserOptions;  // _23_m0[2].xyzw _23_m0[3].xyzw _23_m0[4].xyzw _23_m0[5].xyzw
	float4 u9;       // _23_m0[6].xyzw
	float u10;       // _23_m0[7].x
	float u11;       // _23_m0[7].y
	int u12;         // _23_m0[7].z
	int u13;         // _23_m0[7].w
	float4 u14;      // _23_m0[8].xyzw
}; // float4[9]

struct HDRCompositeData
{
	float4 HighlightsColorFilter;
	float4 ColorFilter;
	float  HableSaturation;
	float  BrightnessMultiplier;
	float  ContrastIntensity;
	int    i_0; //unused
};

//HDRComposite shader structs start
struct Hable_params
{
	float y0;
	float y1;
};

struct Hable_dstParams
{
	float W;
};

struct Hable_toeSegment
{
	float lnA;
	float B;
};

struct Hable_midSegment
{
	float offsetX;
	float lnA;
};

struct Hable_shoulderSegment
{
	float offsetX;
	float offsetY;
	float lnA;
	float B;
};

struct HableParams
{
	Hable_params          params;
	Hable_dstParams       dstParams;
	Hable_toeSegment      toeSegment;
	Hable_midSegment      midSegment;
	Hable_shoulderSegment shoulderSegment;
	float                 invScale;
	float                 toeEnd;
	float                 shoulderStart;
};

struct HableItmParams
{
	float offsetX;
	float offsetY;
	float scaleX;
	float scaleY;
	float lnA;
	float B;
};

struct HableEvalParams
{
	float params_x0;
	float params_x1;
	float params_overshootX;
	float params_overshootY;
	float toeSegment_lnA_optimised;
	float toeSegment_optimised;
	float toeSegment_B;
	float midSegment_offsetX;
	float midSegment_lnA_optimised;
	float shoulderSegment_lnA;
	float shoulderSegment_B_optimised;
};

struct SDRTonemapByLuminancePP
{
	float minHighlightsColorIn;
	float minHighlightsColorOut;
	bool  needsInverseTonemap;
};

//HDRComposite shader structs end
//HDRComposite end

//ColorGradingMerge start
struct PushConstantWrapper_ColorGradingMerge
{
	float LUT1Percentage;
	float LUT2Percentage;
	float LUT3Percentage;
	float LUT4Percentage;
	float neutralLUTPercentage;
};
//ColorGradingMerge end

//ContrastAdaptiveSharpening start

struct CASConst0
{
	float rcpScalingFactorX;
	float rcpScalingFactorY;
	float otherScalingFactorX; //0.5 * inputSizeInPixelsX * (1.0 / outputSizeInPixelsX) - 0.5
	float otherScalingFactorY; //0.5 * inputSizeInPixelsY * (1.0 / outputSizeInPixelsY) - 0.5
};

struct CASConst1
{
	float sharp;
	uint  sharpAsHalf; //needs to be unpacked
	float rcpScalingFactorXTimes8;
	int   unused;
};

struct ContrastAdaptiveSharpeningData
{
	CASConst0 upscalingConst0;
	CASConst1 upscalingConst1;
	uint4     rectLimits0;
	uint4     rectLimits1;
	float4    unknown0;
}; // float4[9]
//ContrastAdaptiveSharpening end
