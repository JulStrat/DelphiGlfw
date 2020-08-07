(*========================================================================
// Simple multi-window example
// Copyright (c) Camilla Löwy <elmindreda@glfw.org>
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
#include <glad/gl.h>
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

#include <stdio.h>
#include <stdlib.h>
*)

program mwindows;

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

{$APPTYPE Console}

uses
  {$IFDEF FPC}
  (* FPC *)
  SysUtils,
  {$IF Defined(MSWINDOWS) or Defined(Linux)}
  gl, 
  {$ENDIF}
  {$ELSE}  
  (* Delphi *)
  System.SysUtils,
  {$IF Defined(MSWINDOWS)}
  Winapi.OpenGL, 
  {$ELSEIF Defined(MACOS) and not Defined(IOS)}
  Macapi.CocoaTypes, Macapi.OpenGL,
  {$ENDIF}
  {$ENDIF}  
  Math, Neslib.Glfw3 in '..\..\Glfw\Neslib.Glfw3.pas';

const
  colors: array[0..3,0..2] of single =  
        (
            ( 0.95, 0.32, 0.11 ),
            ( 0.50, 0.80, 0.16 ),
            (  0.0, 0.68, 0.94 ),
            ( 0.98, 0.74, 0.04 )
        );
  
var
    xpos, ypos, height: integer;
    description: PAnsiChar;
    windows: array[0..3] of PGLFWwindow;
	i: integer;

begin

    if glfwInit() = 0 then
    begin
        glfwGetError(@description);
        WriteLn(Format('Error: %s', [description]));
        Halt(1);
    end;

    glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
    glfwWindowHint(GLFW_DECORATED, GLFW_FALSE);

    glfwGetMonitorWorkarea(glfwGetPrimaryMonitor(), @xpos, @ypos, nil, @height);

    for i := 0 to 3 do
    begin
        if i > 0 then
            glfwWindowHint(GLFW_FOCUS_ON_SHOW, GLFW_FALSE);

        windows[i] := glfwCreateWindow(height div 5, height div 5, 'Multi-Window Example', nil, nil);
        if windows[i] = nil then
        begin
            glfwGetError(@description);
            WriteLn(Format('Error: %s', [description]));
            glfwTerminate();
            Halt(1);
        end;

        glfwSetWindowPos(windows[i],
                         xpos + (height div 5) * (1 + (i and 1)),
                         ypos + (height div 5) * (1 + (i shr 1)));
        glfwSetInputMode(windows[i], GLFW_STICKY_KEYS, GLFW_TRUE);

        glfwMakeContextCurrent(windows[i]);
        //gladLoadGL(glfwGetProcAddress);
        glClearColor(colors[i][0], colors[i][1], colors[i][2], 1.0);
    end;

    for i := 0 to 3 do
        glfwShowWindow(windows[i]);

    while True do
    begin
        for i := 0 to 3 do
        begin
            glfwMakeContextCurrent(windows[i]);
            glClear(GL_COLOR_BUFFER_BIT);
            glfwSwapBuffers(windows[i]);

            if (glfwWindowShouldClose(windows[i]) or 
                glfwGetKey(windows[i], GLFW_KEY_ESCAPE)) <> 0 then
            begin
                glfwTerminate();
                Halt(0);
            end
        end;

        glfwWaitEvents();
    end;
end.
