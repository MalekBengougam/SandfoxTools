#version 120

attribute vec4 a_Position;
attribute vec2 a_UV;


uniform mat4 u_WorldMatrix;
uniform mat4 u_ViewMatrix;
uniform mat4 u_ProjectionMatrix;

varying vec2 v_UV;

void main(void)
{
	// conversion des positions en coordonnees de textures normalisees
	// suppose que les positions des sommets sont normalisees NDC
	//v_UV = a_Position.xy * 0.5 + 0.5;
	v_UV = a_UV;
	gl_Position = u_ProjectionMatrix * u_ViewMatrix * u_WorldMatrix * a_Position;
}