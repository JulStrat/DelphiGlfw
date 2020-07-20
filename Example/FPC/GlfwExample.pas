program GlfwExample;

{$IFDEF FPC}
{$MODE Delphi}
{$ENDIF}

{$APPTYPE Console}

uses
  {$IFNDEF FPC}System.SysUtils{$ELSE}SysUtils{$ENDIF},
  {$IF Defined(MSWINDOWS)}
  {$IFNDEF FPC}
  Winapi.OpenGL, Winapi.OpenGLExt,
  {$ELSE}
  gl, glext,
  {$ENDIF}
  {$ELSEIF Defined(MACOS) and not Defined(IOS)}
  Macapi.CocoaTypes,
  Macapi.OpenGL,
  {$ELSEIF Defined(Linux)}
  gl, glext,
  {$ENDIF}
  Neslib.Glfw3 in '..\..\Glfw\Neslib.Glfw3.pas';

procedure ErrorCallback(error: Integer; const description: PAnsiChar); cdecl;
var
  Desc: String;
begin
  Desc := String(AnsiString(description));
  raise Exception.CreateFmt('GLFW Error %d: %s', [error, Desc]);
end;

procedure KeyCallback(window: PGLFWwindow; key, scancode, action, mods: Integer); cdecl;
begin
  if (key = GLFW_KEY_ESCAPE) and (action = GLFW_PRESS) then
    glfwSetWindowShouldClose(window, GLFW_TRUE);
end;

procedure Run;
var
  Window: PGLFWwindow;
  Ratio: Single;
  Width, Height: Integer;

begin
  glfwSetErrorCallback(ErrorCallback);
  if (glfwInit = 0) then
    raise Exception.Create('Unable to initialize GLFW');

  Window := glfwCreateWindow(640, 480, 'Simple example', nil, nil);
  if (Window = nil) then
  begin
    glfwTerminate;
    raise Exception.Create('Unable to create GLFW window');
  end;

  glfwMakeContextCurrent(Window);
  glfwSwapInterval(1);
  glfwSetKeyCallback(Window, KeyCallback);

  while (glfwWindowShouldClose(Window) = 0) do
  begin
    glfwGetFramebufferSize(Window, @width, @height);
    Ratio := Width / Height;
    glViewport(0, 0, Width, Height);
    glClear(GL_COLOR_BUFFER_BIT);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(-Ratio, Ratio, -1.0, 1.0, 1.0, -1.0);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glRotatef(glfwGetTime() * 50.0, 0.0, 0.0, 1.0);
    glBegin(GL_TRIANGLES);
    glColor3f(1.0, 0.0, 0.0);
    glVertex3f(-0.6, -0.4, 0.0);
    glColor3f(0.0, 1.0, 0.0);
    glVertex3f(0.6, -0.4, 0.0);
    glColor3f(0.0, 0.0, 1.0);
    glVertex3f(0.0, 0.6, 0.0);
    glEnd();
    glfwSwapBuffers(Window);
    glfwPollEvents();
  end;

  glfwDestroyWindow(Window);
  glfwTerminate;
end;

begin
  Run;
end.
