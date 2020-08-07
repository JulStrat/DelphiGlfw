(*
 * 3-D gear wheels.  This program is in the public domain.
 *
 * Command line options:
 *    -info      print GL implementation information
 *    -exit      automatically exit after 30 seconds
 *
 *
 * Brian Paul
 *
 *
 * Marcus Geelnard:
 *   - Conversion to GLFW
 *   - Time based rendering (frame rate independent)
 *   - Slightly modified camera that should work better for stereo viewing
 *
 *
 * Camilla Löwy:
 *   - Removed FPS counter (this is not a benchmark)
 *   - Added a few comments
 *   - Enabled vsync
 *)

(*
#if defined(_MSC_VER)
 // Make MS math.h define M_PI
 #define _USE_MATH_DEFINES
#endif

#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <glad/gl.h>
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
*)

program gears;

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

{$APPTYPE Console}

//{$Define USE_GLAD}

uses
  {$IFDEF FPC}
  (* FPC *)
  SysUtils,
  {$IF not Defined(USE_GLAD)}
  gl, 
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

(*
  Draw a gear wheel.  You'll probably want to call this function when
  building a display list since we do a lot of trig here.

  Input:  inner_radius - radius of hole at center
          outer_radius - radius at center of teeth
          width - width of gear 
		  teeth - number of teeth
          tooth_depth - depth of tooth
*)
procedure
gear(inner_radius: GLfloat; outer_radius: GLfloat; width: GLfloat;
  teeth: GLint; tooth_depth: GLfloat);
var
  i: GLint;
  r0, r1, r2: GLfloat;
  angle, da: GLfloat;
  u, v, len: GLfloat;
begin  
  r0 := inner_radius;
  r1 := outer_radius - tooth_depth / 2.0;
  r2 := outer_radius + tooth_depth / 2.0;

  da := 2.0 * PI / teeth / 4.0;

  glShadeModel(GL_FLAT);

  glNormal3f(0.0, 0.0, 1.0);

  (* draw front face *)
  glBegin(GL_QUAD_STRIP);
  for i := 0 to teeth do
  begin
    angle := i * 2.0 * PI / teeth;
    glVertex3f(r0 * cos(angle), r0 * sin(angle), width * 0.5);
    glVertex3f(r1 * cos(angle), r1 * sin(angle), width * 0.5);
    if i < teeth then
	begin
      glVertex3f(r0 * cos(angle), r0 * sin(angle), width * 0.5);
      glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da), width * 0.5);
    end;
  end;
  glEnd();

  (* draw front sides of teeth *)
  glBegin(GL_QUADS);
  da := 2.0 * PI / teeth / 4.0;
  for i := 0 to teeth-1 do
  begin
    angle := i * 2.0 * PI / teeth;

    glVertex3f(r1 * cos(angle), r1 * sin(angle), width * 0.5);
    glVertex3f(r2 * cos(angle + da), r2 * sin(angle + da), width * 0.5);
    glVertex3f(r2 * cos(angle + 2 * da), r2 * sin(angle + 2 * da), width * 0.5);
    glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da), width * 0.5);
  end;
  glEnd();

  glNormal3f(0.0, 0.0, -1.0);

  (* draw back face *)
  glBegin(GL_QUAD_STRIP);
  for i := 0 to teeth do
  begin
    angle := i * 2.0 * PI / teeth;
    glVertex3f(r1 * cos(angle), r1 * sin(angle), -width * 0.5);
    glVertex3f(r0 * cos(angle), r0 * sin(angle), -width * 0.5);
    if i < teeth then
	begin
      glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da), -width * 0.5);
      glVertex3f(r0 * cos(angle), r0 * sin(angle), -width * 0.5);
    end;
  end;
  glEnd();

  (* draw back sides of teeth *)
  glBegin(GL_QUADS);
  da := 2.0 * PI / teeth / 4.0;
  for i := 0 to teeth - 1 do
  begin
    angle := i * 2.0 * PI / teeth;

    glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da), -width * 0.5);
    glVertex3f(r2 * cos(angle + 2 * da), r2 * sin(angle + 2 * da), -width * 0.5);
    glVertex3f(r2 * cos(angle + da), r2 * sin(angle + da), -width * 0.5);
    glVertex3f(r1 * cos(angle), r1 * sin(angle), -width * 0.5);
  end;
  glEnd();

  (* draw outward faces of teeth *)
  glBegin(GL_QUAD_STRIP);
  for i := 0 to teeth - 1 do
  begin
    angle := i * 2.0 * PI / teeth;

    glVertex3f(r1 * cos(angle), r1 * sin(angle), width * 0.5);
    glVertex3f(r1 * cos(angle), r1 * sin(angle), -width * 0.5);
    u := r2 * cos(angle + da) - r1 * cos(angle);
    v := r2 * sin(angle + da) - r1 * sin(angle);
    len := sqrt(u * u + v * v);
    u := u / len;
    v := v / len;
    glNormal3f(v, -u, 0.0);
    glVertex3f(r2 * cos(angle + da), r2 * sin(angle + da), width * 0.5);
    glVertex3f(r2 * cos(angle + da), r2 * sin(angle + da), -width * 0.5);
    glNormal3f(cos(angle), sin(angle), 0.0);
    glVertex3f(r2 * cos(angle + 2 * da), r2 * sin(angle + 2 * da), width * 0.5);
    glVertex3f(r2 * cos(angle + 2 * da), r2 * sin(angle + 2 * da), -width * 0.5);
    u := r1 * cos(angle + 3 * da) - r2 * cos(angle + 2 * da);
    v := r1 * sin(angle + 3 * da) - r2 * sin(angle + 2 * da);
    glNormal3f(v, -u, 0.0);
    glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da), width * 0.5);
    glVertex3f(r1 * cos(angle + 3 * da), r1 * sin(angle + 3 * da), -width * 0.5);
    glNormal3f(cos(angle), sin(angle), 0.0);
  end;

  glVertex3f(r1 * cos(0), r1 * sin(0), width * 0.5);
  glVertex3f(r1 * cos(0), r1 * sin(0), -width * 0.5);

  glEnd();

  glShadeModel(GL_SMOOTH);

  (* draw inside radius cylinder *)
  glBegin(GL_QUAD_STRIP);
  for i := 0 to teeth do
  begin
    angle := i * 2.0 * PI / teeth;
    glNormal3f(-cos(angle), -sin(angle), 0.0);
    glVertex3f(r0 * cos(angle), r0 * sin(angle), -width * 0.5);
    glVertex3f(r0 * cos(angle), r0 * sin(angle), width * 0.5);
  end;
  glEnd();
end;

var
  view_rotx: GLfloat = 20.0;
  view_roty: GLfloat = 30.0;
  view_rotz: GLfloat = 0.0;
  gear1: GLint = 0;
  gear2: GLint = 0;
  gear3: GLint = 0;
  angle: GLfloat = 0.0;

(* OpenGL draw function & timing *)
procedure draw();
begin
  glClearColor(0.0, 0.0, 0.0, 0.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  glPushMatrix();
  glRotatef(view_rotx, 1.0, 0.0, 0.0);
  glRotatef(view_roty, 0.0, 1.0, 0.0);
  glRotatef(view_rotz, 0.0, 0.0, 1.0);

  glPushMatrix();
  glTranslatef(-3.0, -2.0, 0.0);
  glRotatef(angle, 0.0, 0.0, 1.0);
  glCallList(gear1);
  glPopMatrix();

  glPushMatrix();
  glTranslatef(3.1, -2.0, 0.0);
  glRotatef(-2.0 * angle - 9.0, 0.0, 0.0, 1.0);
  glCallList(gear2);
  glPopMatrix();

  glPushMatrix();
  glTranslatef(-3.1, 4.2, 0.0);
  glRotatef(-2.0 * angle - 25.0, 0.0, 0.0, 1.0);
  glCallList(gear3);
  glPopMatrix();

  glPopMatrix();
end;

(* update animation parameters *)
{$J+}
procedure animate(); inline;
begin
  angle := 100.0 * glfwGetTime();
end;

(* change view angle, exit upon ESC *)
procedure key(window: PGLFWwindow; k, s, action, mods: integer); cdecl;
begin
  if  action <> GLFW_PRESS then Exit;

  case k of 
    GLFW_KEY_Z:
      if mods and GLFW_MOD_SHIFT <> 0 then view_rotz := view_rotz - 5.0
      else view_rotz := view_rotz + 5.0;

    GLFW_KEY_ESCAPE: glfwSetWindowShouldClose(window, GLFW_TRUE);

    GLFW_KEY_UP: view_rotx := view_rotx + 5.0;

    GLFW_KEY_DOWN: view_rotx := view_rotx - 5.0;

    GLFW_KEY_LEFT: view_roty := view_roty + 5.0;

    GLFW_KEY_RIGHT: view_roty := view_roty - 5.0;
  end;
end;
{$J-}

(* new window size *)
procedure reshape(window: PGLFWwindow; width, height: integer); cdecl;
var
  h: GLfloat; 
  xmax, znear, zfar: GLfloat;

begin
  h := GLfloat(height) / GLfloat(width);
  znear := 5.0;
  zfar  := 30.0;
  xmax  := znear * 0.5;
  glViewport( GLInt(0), GLInt(0), GLsizei(width), GLsizei(height) );
  glMatrixMode( GL_PROJECTION );
  glLoadIdentity();
  glFrustum( -xmax, xmax, -xmax*h, xmax*h, znear, zfar );
  glMatrixMode( GL_MODELVIEW );
  glLoadIdentity();
  glTranslatef( 0.0, 0.0, -20.0 );
end;

(* program & OpenGL initialization *)
procedure init();

const
  pos: array[0..3] of GLfloat = (5.0, 5.0, 10.0, 0.0);
  red: array[0..3] of GLfloat = (0.8, 0.1, 0.0, 1.0);
  green: array[0..3] of GLfloat = (0.0, 0.8, 0.2, 1.0);
  blue: array[0..3] of GLfloat = (0.2, 0.2, 1.0, 1.0);

begin

  glLightfv(GL_LIGHT0, GL_POSITION, @pos);
  glEnable(GL_CULL_FACE);
  glEnable(GL_LIGHTING);
  glEnable(GL_LIGHT0);
  glEnable(GL_DEPTH_TEST);

  (* make the gears *)
  gear1 := glGenLists(1);
  glNewList(gear1, GL_COMPILE);
  glMaterialfv(GL_FRONT, GL_AMBIENT_AND_DIFFUSE, @red);
  gear(1.0, 4.0, 1.0, 20, 0.7);
  glEndList();

  gear2 := glGenLists(1);
  glNewList(gear2, GL_COMPILE);
  glMaterialfv(GL_FRONT, GL_AMBIENT_AND_DIFFUSE, @green);
  gear(0.5, 2.0, 2.0, 10, 0.7);
  glEndList();

  gear3 := glGenLists(1);
  glNewList(gear3, GL_COMPILE);
  glMaterialfv(GL_FRONT, GL_AMBIENT_AND_DIFFUSE, @blue);
  gear(1.3, 2.0, 0.5, 10, 0.7);
  glEndList();

  glEnable(GL_NORMALIZE);
end;

var
    window: PGLFWwindow;
    width, height: integer;
	
begin
    if glfwInit() = 0 then
    begin
        WriteLn('Failed to initialize GLFW');
        Halt(1); //Exit(EXIT_FAILURE);
    end;

    glfwWindowHint(GLFW_DEPTH_BITS, 16);
    //glfwWindowHint(GLFW_TRANSPARENT_FRAMEBUFFER, GLFW_TRUE);

    //window := glfwCreateWindow( 300, 300, 'Gears', nil, nil );
	window := glfwCreateWindow( 640, 480, 'Gears', nil, nil );
    if window = nil then
    begin
        WriteLn('Failed to open GLFW window');
        glfwTerminate();
        Halt(1); //Exit(EXIT_FAILURE);
    end;
    
	(* Set callback functions *)
    glfwSetFramebufferSizeCallback(window, reshape);
    glfwSetKeyCallback(window, key);

    glfwMakeContextCurrent(window);

    {$IF Defined(USE_GLAD)}
	if not gladLoadGL(@glfwGetProcAddress) then
    begin
        WriteLn('Failed to load GL');
        glfwTerminate();
        Halt(1); //Exit(EXIT_FAILURE);
    end;
	{$ENDIF}
	
	glfwSwapInterval( 1 );
    glfwGetFramebufferSize(window, @width, @height);
    reshape(window, width, height);
    (* Parse command-line options *)
    init();

    (* Main loop *)
    while glfwWindowShouldClose(window) = 0 do
    begin
        (* Draw gears *)
        draw();

        (* Update animation *)
        animate();

        (* Swap buffers *)
        glfwSwapBuffers(window);
        glfwPollEvents();
    end;

    glfwTerminate();

    Halt(0); //exit( EXIT_SUCCESS );
end.
