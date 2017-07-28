﻿Shader "Pixel Art/Lit Textured Dithered" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _Dither ("Dithering amount", float) = .5
        _Glow ("Glow Intensity", float) = 1
    }
    SubShader { 
        Pass{
            Tags { "RenderType"="Opaque" "LightMode" = "Always" "LightMode" = "ForwardBase"}
            CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma multi_compile_fwdbase
            	#pragma multi_compile DITHER_ON DITHER_OFF 
				#pragma glsl_no_auto_normalization 
                #pragma fragmentoption ARB_precision_hint_fastest               
                #include "UnityCG.cginc"
                #include "AutoLight.cginc"
                #include "Lighting.cginc"
                uniform sampler2D _MainTex;
                uniform fixed4 _MainTex_ST;
                uniform fixed4 _Color;          // Made this a fixed4, you won't get greater precision using fixed here.
                uniform sampler2D _DitherTex;
                fixed _PixelSnap;
                fixed4 _DitherScale;
                fixed _Dither;
                fixed _Glow;
                struct a2v  {
                    float4 vertex : POSITION;
                    fixed3 normal : NORMAL;
                    fixed4 texcoord : TEXCOORD0;
                    fixed4 color: COLOR;

                };
 
                struct v2f  {
                    float4 pos : SV_POSITION;
                    fixed2 uv : TEXCOORD0;          // Made this a fixed, fixed sometimes isn't precise enough for UVs.
                    fixed3 normal : TEXCOORD1;      // Added this to store vertex normal for fragment shader.
                    fixed3 lightDir : TEXCOORD2;    // Added this to store light direction for fragment shader.
                    fixed4 color: COLOR;
                    fixed4 screenPos: TEXCOORD5;
                    LIGHTING_COORDS(3, 4)
                };
 
                v2f vert(a2v  v){
                    v2f o;
                    o.pos = UnityObjectToClipPos(v.vertex);
                    fixed4 ObjDepth = mul(UNITY_MATRIX_IT_MV, v.vertex);
			        // Snapping params
					float hpcX = _ScreenParams.x * _PixelSnap;
					float hpcY = _ScreenParams.y * _PixelSnap;
				#ifdef UNITY_HALF_TEXEL_OFFSET
					float hpcOX = -0.5;
					float hpcOY = 0.5;
				#else
					float hpcOX = 0;
					float hpcOY = 0;
				#endif	
					// Snap
					float posi = floor((o.pos.x / o.pos.w) * hpcX + 0.5f) + hpcOX;
					o.pos.x = posi / hpcX * o.pos.w;

					posi = floor((o.pos.y / o.pos.w) * hpcY + 0.5f) + hpcOY;
					o.pos.y = posi / hpcY * o.pos.w;
					
                    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
 					o.color = v.color;
                    // Here we set up the normal and light dir for use in the fragment shader, both in object space.
                    o.normal = v.normal;
                    o.lightDir = ObjSpaceLightDir(v.vertex);
                    o.screenPos = ComputeScreenPos(o.pos);
 					o.screenPos.w = ObjDepth.z/4;
 					TRANSFER_VERTEX_TO_FRAGMENT(o)
                    return o;
                }
 
                // Made this a fixed4, you won't gain precision with a fixed.
                fixed4 frag(v2f i, out float depth : DEPTH) : COLOR
                {
                	fixed3 colors = tex2D(_MainTex, i.uv);//*(1+dither);
                    // Normalize the vectors to fix interpolation shortening.
                    i.normal = normalize(i.normal);
                    i.lightDir = normalize(i.lightDir); 
                    // Get dot product to use as ramp UV coords.
                    // Transformed from -1 to 1 range to 0 - 1 range so it can use the full dimensions of the ramp texture.
                    fixed NdotL = dot(i.normal, i.lightDir);
                    fixed shadow = saturate(SHADOW_ATTENUATION(i));
                    fixed dither = 0;
                    #if DITHER_ON
	                    dither = tex2D(_DitherTex,i.screenPos*_DitherScale).r;// _Color.rgb; 
	                    dither -= .5;
	                    dither *= .025*_Dither; 
	                    //dither *= .5;
 					#endif
 					// Put the vector maths in brackets so it doesn't try and do scalar-vector maths where it doesn't need to.
                   fixed4 c = saturate(UNITY_LIGHTMODEL_AMBIENT*4+i.color.b*10	);
                   //fixed amb = ((i.color.r)*(c.r+c.g+c.b)*.33333);
                    //fixed shade = saturate(saturate((NdotL+dither*8)*2500-1250)*.15+.85+i.color.b*2);
                    //fixed2 newCoords = fixed2(lerp(amb,max(NdotL,amb),shadow+dither*4)+dither-(saturate(1-i.screenPos.w-.5)*(1-_DistanceDarken)),i.uv.y);
                    fixed shade = min(saturate(NdotL*100-60+dither*300)+.45,saturate(NdotL*100-50+dither*50)) ;
                   
                    c.rgb = colors * ((c.rgb*i.color.r-dither/2)+_LightColor0.rgb*2*min(shadow,shade));//,saturate(NdotL*100)+.375) );
                    c.rgb += saturate((1-saturate((i.color.g)*(dither*25+1)))*saturate(i.color.r-.75)*UNITY_LIGHTMODEL_AMBIENT*3);
                    //c.rgb *= shade;
                    c.rgb = lerp(c.rgb, colors.rgb*_Glow, i.color.b);
                    c.rgb *= _Color.rgb;
                    //c.rgb = saturate(1-i.screenPos.w-.5)*.5;
                    c.a = 1.0;

                    return c;
                }
            ENDCG
        }
   	}
    Fallback "VertexLit"
}