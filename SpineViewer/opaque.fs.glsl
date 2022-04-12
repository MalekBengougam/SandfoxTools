#version 120

#define PI 3.14159265

varying vec3 v_Position;
varying vec3 v_Normal;
varying vec2 v_TexCoords;
varying vec3 v_Tangent;
varying float v_Handedness;
varying vec3 v_CameraPosition;

struct Material {
	//vec3 AmbientColor;
	vec3 DiffuseColor;
	//vec3 SpecularColor;
	float Roughness;
	float Metalness;
};
uniform Material u_Material;

//uniform vec3 u_CameraPosition;

uniform sampler2D u_DiffuseTexture;
uniform sampler2D u_PBRTexture;
uniform sampler2D u_AmbientTexture;
uniform sampler2D u_EmissiveTexture;
uniform sampler2D u_NormalTexture;

uniform sampler2D u_ReflectionTexture;


// calcul du facteur diffus, suivant la loi du cosinus de Lambert
float Lambert(vec3 N, vec3 L)
{
	return max(0.0, dot(N, L));
}

vec3 Fresnel(vec3 f0, float cosTheta, float roughness)
{
	float schlick = pow(1.0 - cosTheta, 5.0);
	return f0 + ((max(vec3(1.0 - roughness), f0) - f0)*schlick);
}

// calcul du facteur speculaire, methode de Phong
float Phong(vec3 N, vec3 L, vec3 V, float shininess)
{
	float normalization = (shininess+2.0)/(2.0*PI); 
	// reflexion du vecteur incident I (I = -L)
	// suivant la loi de ibn Sahl / Snell / Descartes
	vec3 R = reflect(-L, N);
	return normalization * pow(max(0.0, dot(R, V)), shininess);
}

// calcul du facteur speculaire, methode Blinn-Phong
float BlinnPhong(vec3 N, vec3 H, float shininess)
{
	float normalization = (shininess+8.0)/(8.0*PI);
	// reflexion inspire du modele micro-facette (H approxime la normale de la micro-facette)
	
	return normalization * pow(max(0.0, dot(N, H)), shininess);
}

float Gotanda(vec3 N, vec3 H, float NdotL, float NdotV, float shininess)
{
	float normalization = /*0.0397436*shininess + 0.0856832;*/(shininess+2.0)/(8.0*PI);
	// reflexion inspire du modele micro-facette (H approxime la normale de la micro-facette)
	
	return normalization * pow(max(0.0, dot(N, H)), shininess) / max(NdotL, NdotV);
}

const vec3 dielectricSpecular = vec3(0.04);
// directions des deux lumieres (fixes)
const vec3 L[2] = vec3[2](normalize(vec3(0.0, 0.0, 1.0)), normalize(vec3(0.0, 0.0, -1.0)));
const vec3 lightColor[2] = vec3[2](vec3(1.0, 1.0, 1.0), vec3(0.2, 0.8, 0.5));
const float attenuation = 1.0; // on suppose une attenuation faible ici
// theoriquement, l'attenuation naturelle est proche de 1 / distance²

void main(void)
{
	vec4 baseTexel = texture2D(u_DiffuseTexture, v_TexCoords);
	
	vec3 N = normalize(v_Normal);
	vec3 T = normalize(v_Tangent);
	vec3 B = cross(N, T) * v_Handedness;
	mat3 TBN = mat3(T, B, N);
	vec3 Ntspace = (texture2D(u_NormalTexture, v_TexCoords).rgb * 2.0 - 1.0);
	N = normalize(TBN * Ntspace);

	vec3 V = normalize(v_CameraPosition - v_Position);

	float NdotV = max(dot(N, V), 0.001);

	// decompression gamma, les couleurs des texels ont ete specifies dans l'espace colorimetrique
	// du moniteur (en sRGB) il faut donc convertir en RGB lineaire pour que les maths soient corrects
	// il faut de preference utiliser le hardware pour cette conversion 
	// ce qui peut se faire pour chaque texture en specifiant le(s) format(s) interne(s) GL_SRGB8(_ALPHA8)
	//baseTexel.rgb = pow(baseTexel.rgb, vec3(2.2));
	vec3 baseColor = baseTexel.rgb * pow(u_Material.DiffuseColor, vec3(2.2));
	
	vec3 pbrFactors = texture2D(u_PBRTexture, v_TexCoords).rgb;
	float directAO = texture2D(u_AmbientTexture, v_TexCoords).r;
	float perceptual_roughness = u_Material.Roughness * pbrFactors.g;
	float metallic = u_Material.Metalness * pbrFactors.b;
	float roughness = perceptual_roughness * perceptual_roughness; // alpha=perceptual²

	float shininess = (2.0 / max(roughness*roughness, 0.0000001)) - 2.0;

	vec3 specularReflectance = mix(dielectricSpecular, baseColor, metallic);
	
	vec3 directColor = vec3(0.0);
	vec3 directDiffuse = vec3(0.0);
	vec3 directSpecular = vec3(0.0);
	//vec3 albedo = baseColor / PI;

	int i = 0; //for (int i = 0; i < 2; i++)
	{
		// les couleurs diffuse et speculaire traduisent l'illumination directe de l'objet
		float NdotL = Lambert(N, L[i]);

		vec3 H = normalize(L[i] + V);
		float VdotH = max(dot(V, H), 0.001);

		vec3 Ks = Fresnel(specularReflectance, VdotH, 0.0);
		
		vec3 specularColor = Ks * Gotanda(N, H, NdotL, NdotV, shininess);
		
		//float Kd = (1.0 - dielectricSpecular.r); // methode 1 : 1 - F(0) 
		vec3 Kd = vec3(1.0) - specularReflectance;	// methode 2 : balance de F(0) cf. Gotanda 2010 eq. v2
		//vec3 Kd = vec3(1.0) - Ks;				// methode 3 : balance du fresnel
		//vec3 Kd = Fresnel(vec3(1.0) - specularReflectance, NdotL, 0.0);  // methode 4 : Gotanda 2010

		vec3 diffuseColor = baseColor * Kd * (1.0 - metallic);
		
		directDiffuse += diffuseColor * NdotL;
		directSpecular += specularColor * NdotL;
		directColor += ((diffuseColor + specularColor) / PI) * NdotL; // * lightColor[i] * attenuation;
	}

	//
	// la couleur ambiante traduit une approximation de l'illumination indirecte de l'objet
	//

	vec3 R = N;// N car diffuse IBL 
	// calc miplevel
	vec3 dx = dFdx(R), dy = dFdy(R);
	float d = max(dot(dx,dx), dot(dy,dy));
	float mipLevel = 0.5 * log2(d) + 8.0; // + bias 
	//float mipLevel = 12.0-2.0;
	vec2 envmapUV = vec2(atan(R.z, R.x), acos(R.y));
	envmapUV *= vec2(1.0/(2*PI), 1.0/PI);
	//envmapUV += 0.5;
	vec3 diffuseIrradiance = texture2DLod(u_ReflectionTexture, envmapUV, mipLevel).rgb;
	// exposition
	//const float exposure = 0.1;
	//diffuseIrradiance = vec3(1.0) - exp(-diffuseIrradiance * exposure);

	vec3 indirectKs = Fresnel(specularReflectance, NdotV, roughness);
	R = reflect(-V, N);
	envmapUV = vec2(atan(R.z, R.x), acos(R.y));
	envmapUV *= vec2(1.0/(2*PI), 1.0/PI);
	//mipLevel = 0.5*(23-1-log2(shininess+1)); // Phong
	mipLevel = 0;//0.5*(23+1-log2(shininess+2)); // Gotanda (simplifie)
	vec3 indirectSpecular = indirectKs * texture2DLod(u_ReflectionTexture, envmapUV, mipLevel).rgb;

	vec3 indirectKd = vec3(1.0) - indirectKs;
	vec3 indirectDiffuse = (indirectKd * diffuseIrradiance);
	indirectDiffuse *= 1.0 - metallic;

	vec3 indirectColor = (indirectDiffuse + indirectSpecular) / PI;
	
	//
	// couleur emissive
	//
	vec4 emissive = texture2D(u_EmissiveTexture, v_TexCoords);
	vec3 emissiveColor = emissive.rgb * emissive.a;
	
	//
	// couleur finale
	//
	vec3 color = emissiveColor + directAO * PI * (directColor + indirectColor);
	
	// debug
	//color = (directDiffuse+indirectDiffuse);
	//color = indirectSpecular;
	//color *= PI;

	// Tone mapping : Reinhardt
	color = color / (color + vec3(1.0));

	/// correction gamma (pas necessaire ici si glEnable(GL_FRAMEBUFFER_SRGB))
	///color = pow(color, vec3(1.0 / 2.2));

	gl_FragColor = vec4(color, 1.0);
}
