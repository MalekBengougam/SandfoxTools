#version 120

attribute vec3 a_Position;
attribute vec3 a_Normal;
attribute vec2 a_TexCoords;
attribute vec4 a_Tangent;

uniform mat4 u_WorldMatrix;
uniform mat4 u_ViewMatrix;
uniform mat4 u_ProjectionMatrix;

varying vec3 v_Position;
varying vec3 v_Normal;
varying vec2 v_TexCoords;
varying vec3 v_Tangent;
varying float v_Handedness;
varying vec3 v_CameraPosition;

void main(void)
{
	v_TexCoords = vec2(a_TexCoords.x, a_TexCoords.y);

	v_Position = vec3(u_WorldMatrix * vec4(a_Position, 1.0));
	// note: techniquement il faudrait passer une normal matrix du C++ vers le GLSL
	// pour les raisons que l'on a vu en cours. A defaut on pourrait la calculer ici
	// mais les fonctions inverse() et transpose() n'existe pas dans toutes les versions d'OpenGL
	// on suppose ici que la matrice monde -celle appliquee a v_Position- est orthogonale (sans deformation des axes)
	v_Normal = mat3(u_WorldMatrix) * a_Normal;
	v_Tangent = mat3(u_WorldMatrix) * a_Tangent.xyz;
	v_Handedness = a_Tangent.w;
	v_CameraPosition = -vec3(u_ViewMatrix[3]) * mat3(u_ViewMatrix);
	gl_Position = u_ProjectionMatrix * u_ViewMatrix * u_WorldMatrix * vec4(a_Position, 1.0);
}