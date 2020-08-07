(*
//========================================================================
// Heightmap example program using OpenGL 3 core profile
// Copyright (c) 2010 Olivier Delannoy
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would
//    be appreciated but is not required.
//
// 2. Altered source versions must be plainly marked as such, and must not
//    be misrepresented as being the original software.
//
// 3. This notice may not be removed or altered from any source
//    distribution.
//
//========================================================================
*)

(*
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <assert.h>
#include <stddef.h>

#include <glad/gl.h>
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
*)

program heightmap;

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

{$APPTYPE Console}
uses
  {$IFDEF FPC}
  (* FPC *)
  SysUtils,
  {$IF not Defined(USE_GLAD)}
  gl, glext, 
  {$ELSE}
  glad_gl in '..\..\glad\glad_gl.pas',
  {$ENDIF}

  {$ELSE}  
  (* Delphi *)
  System.SysUtils,
  {$IF Defined(MSWINDOWS)}
    {$IF not Defined(USE_GLAD)}
    Winapi.OpenGL, 
    {$ELSE}
    glad_gl in '..\..\glad\glad_gl.pas',
    {$ENDIF}
  {$ELSEIF Defined(MACOS) and not Defined(IOS)}
  Macapi.CocoaTypes, Macapi.OpenGL,
  {$ENDIF}
  {$ENDIF}  
  Math, Neslib.Glfw3 in '..\..\Glfw\Neslib.Glfw3.pas';

const
(* Map height updates *)
  MAX_CIRCLE_SIZE  = 5.0;
  MAX_DISPLACEMENT = 1.0;
  DISPLACEMENT_SIGN_LIMIT = 0.3;
  MAX_ITER = 200;
  NUM_ITER_AT_A_TIME = 1;

(* Map general information *)
  MAP_SIZE = 10.0;
  MAP_NUM_VERTICES = 80;
  MAP_NUM_TOTAL_VERTICES = MAP_NUM_VERTICES * MAP_NUM_VERTICES;
  MAP_NUM_LINES = 3 * (MAP_NUM_VERTICES - 1) * (MAP_NUM_VERTICES - 1) + 
    2 * (MAP_NUM_VERTICES - 1);

(**********************************************************************
 * Default shader programs
 *********************************************************************)

  vertex_shader_text: PAnsiChar =
    '#version 150'#10
    + 'uniform mat4 project;'#10
    + 'uniform mat4 modelview;'#10
    + 'in float x;'#10
    + 'in float y;'#10
    + 'in float z;'#10
    + ''#10
    + 'void main()'#10
    + '{'#10
    + '   gl_Position = project * modelview * vec4(x, y, z, 1.0);'#10
    + '}'#10;

  fragment_shader_text: PAnsiChar =
    '#version 150'#10
    + 'out vec4 color;'#10
    + 'void main()'#10
    + '{'#10
    + '    color = vec4(0.2, 1.0, 0.2, 1.0);'#10
    + '}'#10;

(**********************************************************************
 * Values for shader uniforms
 *********************************************************************)

(* Frustum configuration *)
  view_angle: GLfloat = 45.0;
  aspect_ratio: GLfloat = 4.0/3.0;
  z_near: GLfloat = 1.0;
  z_far: GLfloat = 100.0;

(* Projection matrix *)
  projection_matrix: array[0..15] of GLfloat = (
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
);

(* Model view matrix *)
  modelview_matrix: array[0..15] of GLfloat = (
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0
);

var
(**********************************************************************
 * Heightmap vertex and index data
 *********************************************************************)

  map_vertices: array[0..2, 0..MAP_NUM_TOTAL_VERTICES-1] of GLfloat;
  map_line_indices: array[0..2*MAP_NUM_LINES-1] of GLuint;

(* Store uniform location for the shaders
 * Those values are setup as part of the process of creating
 * the shader program. They should not be used before creating
 * the program.
 *)
  mesh: GLuint;
  mesh_vbo: array[0..3] of GLuint;

(**********************************************************************
 * OpenGL helper functions
 *********************************************************************)

(* Creates a shader object of the specified type using the specified text
 *)
function make_shader(&type: GLenum; var text: PAnsiChar): GLuint;
var
    shader: GLuint;
    shader_ok: GLint;
    log_length: GLsizei;
    info_log: array[0..8191] of AnsiChar;
	
begin
    shader := glCreateShader(&type);

    if shader <> 0 then
    begin
        glShaderSource(shader, 1, @text, nil);
        glCompileShader(shader);
        glGetShaderiv(shader, GL_COMPILE_STATUS, @shader_ok);
        if shader_ok <> GL_TRUE then
        begin
			if &type = GL_FRAGMENT_SHADER then
              WriteLn(Format('ERROR: Failed to compile %s shader', ['fragment']))
			else
			  WriteLn(Format('ERROR: Failed to compile %s shader', ['vertex'])); 
            glGetShaderInfoLog(shader, 8192, @log_length, @info_log);
            WriteLn(Format('ERROR: %s', [info_log]));
            glDeleteShader(shader);
            shader := 0;
        end;
    end;
    Result := shader;
end;

(* Creates a program object using the specified vertex and fragment text
 *)
function make_shader_program(vs_text: PAnsiChar; fs_text: PAnsiChar): GLuint;
var
    &program: GLuint = 0;
    program_ok: GLint;
    vertex_shader: GLuint = 0;
    fragment_shader: GLuint = 0;
    log_length: GLsizei;
    info_log: array[0..8191] of PAnsiChar;

begin	
    vertex_shader := make_shader(GL_VERTEX_SHADER, vs_text);

    if vertex_shader <> 0 then
    begin
        fragment_shader := make_shader(GL_FRAGMENT_SHADER, fs_text);
        if fragment_shader <> 0 then
        begin
            (* make the program that connect the two shader and link it *)
            &program := glCreateProgram();
            if &program <> 0 then
            begin
                (* attach both shader and link *)
                glAttachShader(&program, vertex_shader);
                glAttachShader(&program, fragment_shader);
                glLinkProgram(&program);
                glGetProgramiv(&program, GL_LINK_STATUS, @program_ok);

                if program_ok <> GL_TRUE then
                begin
                    WriteLn('ERROR, failed to link shader program');
                    glGetProgramInfoLog(&program, 8192, @log_length, @info_log);
                    WriteLn(Format('ERROR: %s', [PAnsiChar(@info_log)]));
                    glDeleteProgram(&program);
                    glDeleteShader(fragment_shader);
                    glDeleteShader(vertex_shader);
                    &program := 0;
                end;
            end;
        end
        else
        begin
            WriteLn('ERROR: Unable to load fragment shader');
            glDeleteShader(vertex_shader);
        end
    end
    else
    begin
        WriteLn('ERROR: Unable to load vertex shader');
    end;
    Result := &program;
end;

(**********************************************************************
 * Geometry creation functions
 *********************************************************************)

(* Generate vertices and indices for the heightmap
 *)
procedure init_map;
var
    i, j, k: integer;
	step, x, z: GLfloat; 
    ref: integer;
{$IF Defined(DEBUG_ENABLED)}
    beg, &end: integer;
{$ENDIF}
	
begin	
    step := MAP_SIZE / (MAP_NUM_VERTICES - 1);
    x := 0.0;
    z := 0.0;

    (* Create a flat grid *)
    k := 0;
    for i := 0 to MAP_NUM_VERTICES - 1 do
    begin
        for j := 0 to MAP_NUM_VERTICES - 1 do
        begin
            map_vertices[0][k] := x;
            map_vertices[1][k] := 0.0;
            map_vertices[2][k] := z;
            z := z + step;
            k := k + 1;
        end;
        x := x + step;
        z := 0.0;
    end;

{$IF Defined(DEBUG_ENABLED)}
    for (i = 0 ; i < MAP_NUM_TOTAL_VERTICES ; ++i)
    {
        printf ("Vertice %d (%f, %f, %f)\n",
                i, map_vertices[0][i], map_vertices[1][i], map_vertices[2][i]);

    }
{$ENDIF}

    (* create indices *)
    (* line fan based on i
     * i+1
     * |  / i + n + 1
     * | /
     * |/
     * i --- i + n
     *)

    (* close the top of the square *)
    k := 0;
    for i := 0 to MAP_NUM_VERTICES - 2 do
    begin
        map_line_indices[k] := (i + 1) * MAP_NUM_VERTICES - 1;
		Inc(k);
        map_line_indices[k] := (i + 2) * MAP_NUM_VERTICES - 1;
		Inc(k);		
    end;
    (* close the right of the square *)
    for i := 0 to MAP_NUM_VERTICES - 2 do
    begin
        map_line_indices[k] := (MAP_NUM_VERTICES - 1) * MAP_NUM_VERTICES + i;
		Inc(k);		
        map_line_indices[k] := (MAP_NUM_VERTICES - 1) * MAP_NUM_VERTICES + i + 1;
		Inc(k);		
    end;

    for i := 0 to (MAP_NUM_VERTICES - 2) do
    begin
        for j := 0 to (MAP_NUM_VERTICES - 2) do
        begin
            ref := i * (MAP_NUM_VERTICES) + j;
            map_line_indices[k] := ref;
 		    Inc(k);					
            map_line_indices[k] := ref + 1;
		    Inc(k);					

            map_line_indices[k] := ref;
		    Inc(k);					
            map_line_indices[k] := ref + MAP_NUM_VERTICES;
		    Inc(k);					

            map_line_indices[k] := ref;
		    Inc(k);					
            map_line_indices[k] := ref + MAP_NUM_VERTICES + 1;
		    Inc(k);					
        end;
    end;

{$IF Defined(DEBUG_ENABLED)}
    for k := 0 to 2 * MAP_NUM_LINES - 1 ; k += 2)
    begin
        beg := map_line_indices[k];
        &end := map_line_indices[k+1];
        WriteLn(Format('Line %d: %d -> %d (%f, %f, %f) -> (%f, %f, %f)',
                [k / 2, beg, &end,
                map_vertices[0][beg], map_vertices[1][beg], map_vertices[2][beg],
                map_vertices[0][&end], map_vertices[1][&end], map_vertices[2][&end]]));
    end;
{$ENDIF}
end;

procedure generate_heightmap__circle(center_x, center_y, size, displacement: PSingle);
var
  sign: single;
  
begin
    (* random value for element in between [0-1.0] *)
    center_x^ := MAP_SIZE * random(); // (MAP_SIZE * rand()) / (1.0 * RAND_MAX);
    center_y^ := MAP_SIZE * random(); // (MAP_SIZE * rand()) / (1.0 * RAND_MAX);
    size^ := MAX_CIRCLE_SIZE * random(); // (MAX_CIRCLE_SIZE * rand()) / (1.0 * RAND_MAX);
    sign := random(); // (1.0 * rand()) / (1.0 * RAND_MAX);
	if sign < DISPLACEMENT_SIGN_LIMIT then
	  sign := -1.0
	else
	  sign := 1.0;
    displacement^ := sign * MAX_DISPLACEMENT * random(); // (sign * (MAX_DISPLACEMENT * rand())) / (1.0 * RAND_MAX);
end;

(* Run the specified number of iterations of the generation process for the
 * heightmap
 *)
procedure update_map(num_iter: integer);
var
    center_x, center_z, circle_size, disp: single;
    ii: NativeUInt;
    dx, dz, pd, new_height: GLfloat;
	
begin
    Assert(num_iter > 0);
    while num_iter <> 0 do
    begin
        (* center of the circle *)
        generate_heightmap__circle(@center_x, @center_z, @circle_size, @disp);
        disp := disp / 2.0;
        for ii := 0 to MAP_NUM_TOTAL_VERTICES - 1 do
        begin
            dx := center_x - map_vertices[0][ii];
            dz := center_z - map_vertices[2][ii];
            pd := (2.0 * sqrt((dx * dx) + (dz * dz))) / circle_size;
            if abs(pd) <= 1.0 then
            begin
                (* tx, tz is within the circle *)
                new_height := disp + cos(pd*3.14)*disp;
                map_vertices[1][ii] := map_vertices[1][ii] + new_height;
            end;
        end;
        num_iter := num_iter - 1;
    end;
end;

(**********************************************************************
 * OpenGL helper functions
 *********************************************************************)

(* Create VBO, IBO and VAO objects for the heightmap geometry and bind them to
 * the specified program object
 *)
procedure make_mesh(&program: GLuint);
var
    attrloc: GLuint;

begin
    glGenVertexArrays(1, @mesh);
    glGenBuffers(4, mesh_vbo);
    glBindVertexArray(mesh);
    (* Prepare the data for drawing through a buffer inidices *)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh_vbo[3]);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, 
	  sizeof(GLuint)* MAP_NUM_LINES * 2, @map_line_indices, GL_STATIC_DRAW);

    (* Prepare the attributes for rendering *)
    attrloc := glGetAttribLocation(&program, 'x');
    glBindBuffer(GL_ARRAY_BUFFER, mesh_vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, 
	  sizeof(GLfloat) * MAP_NUM_TOTAL_VERTICES, @map_vertices[0][0], GL_STATIC_DRAW);
    glEnableVertexAttribArray(attrloc);
    glVertexAttribPointer(attrloc, 1, GL_FLOAT, GL_FALSE, 0, 0);

    attrloc := glGetAttribLocation(&program, 'z');
    glBindBuffer(GL_ARRAY_BUFFER, mesh_vbo[2]);
    glBufferData(GL_ARRAY_BUFFER, 
	  sizeof(GLfloat) * MAP_NUM_TOTAL_VERTICES, @map_vertices[2][0], GL_STATIC_DRAW);
    glEnableVertexAttribArray(attrloc);
    glVertexAttribPointer(attrloc, 1, GL_FLOAT, GL_FALSE, 0, 0);

    attrloc := glGetAttribLocation(&program, 'y');
    glBindBuffer(GL_ARRAY_BUFFER, mesh_vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, 
	  sizeof(GLfloat) * MAP_NUM_TOTAL_VERTICES, @map_vertices[1][0], GL_DYNAMIC_DRAW);
    glEnableVertexAttribArray(attrloc);
    glVertexAttribPointer(attrloc, 1, GL_FLOAT, GL_FALSE, 0, 0);
end;

(* Update VBO vertices from source data
 *)
procedure update_mesh;
begin
    glBufferSubData(GL_ARRAY_BUFFER, 0, 
	  sizeof(GLfloat) * MAP_NUM_TOTAL_VERTICES, @map_vertices[1][0]);
end;

(**********************************************************************
 * GLFW callback functions
 *********************************************************************)

procedure key_callback(window: PGLFWwindow; key, scancode, action, mods: integer); cdecl;
begin
    case (key) of

      GLFW_KEY_ESCAPE:
        (* Exit program on Escape *)
        glfwSetWindowShouldClose(window, GLFW_TRUE);
    end;
end;

procedure error_callback(error: Integer; const description: PAnsiChar); cdecl;
begin
    WriteLn(Format('Error: %s', [description]));
end;

var
    window: PGLFWwindow;
    iter: integer;
    dt: double;
    last_update_time: double;
    frame: integer;
    f: single;
    uloc_modelview: GLint;
    uloc_project: GLint;
    width, height: integer;
    shader_program: GLuint ;

begin
    glfwSetErrorCallback(error_callback);

    if glfwInit() = 0 then
        Halt(1);

    glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 2);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);

    window := glfwCreateWindow(800, 600, 'GLFW OpenGL3 Heightmap demo', nil, nil);
    if window  = nil then
    begin
        glfwTerminate();
        Halt(1);
    end;

    (* Register events callback *)
    glfwSetKeyCallback(window, key_callback);

    glfwMakeContextCurrent(window);
	
    {$IF Defined(USE_GLAD)}
	if not gladLoadGL(@glfwGetProcAddress) then
    begin
        WriteLn('Failed to load GL');
        glfwTerminate();
        Halt(1); //Exit(EXIT_FAILURE);
    end;
	{$ENDIF}
	
    (* Prepare opengl resources for rendering *)
    shader_program := make_shader_program(vertex_shader_text, fragment_shader_text);
	
    if shader_program = 0 then
    begin
        glfwTerminate();
        Halt(1);
    end;

    glUseProgram(shader_program);
    uloc_project   := glGetUniformLocation(shader_program, 'project');
    uloc_modelview := glGetUniformLocation(shader_program, 'modelview');

    (* Compute the projection matrix *)
    f := 1.0 / tan(view_angle / 2.0);
    projection_matrix[0]  := f / aspect_ratio;
    projection_matrix[5]  := f;
    projection_matrix[10] := (z_far + z_near)/ (z_near - z_far);
    projection_matrix[11] := -1.0;
    projection_matrix[14] := 2.0 * (z_far * z_near) / (z_near - z_far);
    glUniformMatrix4fv(uloc_project, 1, GL_FALSE, projection_matrix);

    (* Set the camera position *)
    modelview_matrix[12] := -5.0;
    modelview_matrix[13] := -5.0;
    modelview_matrix[14] := -20.0;
    glUniformMatrix4fv(uloc_modelview, 1, GL_FALSE, modelview_matrix);

    (* Create mesh data *)
    init_map();
    make_mesh(shader_program);

    (* Create vao + vbo to store the mesh *)
    (* Create the vbo to store all the information for the grid and the height *)

    (* setup the scene ready for rendering *)
    glfwGetFramebufferSize(window, @width, @height);
    glViewport(0, 0, width, height);
    glClearColor(0.0, 0.0, 0.0, 0.0);

    (* main loop *)
    frame := 0;
    iter := 0;
    last_update_time := glfwGetTime();

    while glfwWindowShouldClose(window) = 0 do 
    begin
        frame := frame + 1;
        (* render the next frame *)
        glClear(GL_COLOR_BUFFER_BIT);
        glDrawElements(GL_LINES, 2* MAP_NUM_LINES , GL_UNSIGNED_INT, 0);

        (* display and process events through callbacks *)
        glfwSwapBuffers(window);
        glfwPollEvents();
        (* Check the frame rate and update the heightmap if needed *)
        dt := glfwGetTime();
        if (dt - last_update_time) > 0.2 then
        begin
            (* generate the next iteration of the heightmap *)
            if iter < MAX_ITER then
            begin
                update_map(NUM_ITER_AT_A_TIME);
                update_mesh();
                iter := iter + NUM_ITER_AT_A_TIME;
            end;
            last_update_time := dt;
            frame := 0;
        end;
    end;

    glfwTerminate();
    Halt(0);
end.

