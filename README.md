# godot-3d-runner-controller
Code snippets and ideas to use for a 3d runner/fps controller in godot. Is a mini-demo itself.

Made and tested on v4.1 stable for linux x86_64.

# features
Walking [WASD], sprinting [Shift], jumping [Space. There's even some grace time!], crouching [Ctrl], climbing [Space. See an icon appear in the top left corner to indicate the possibility to climb]. There's even zoom [Alt]! Also: head-bobbing, speed-based FOV.

The test level has a few layers to it - the upper is very basic, one down is with crouch testing and more climbing obstacles, third one is a bit about slopes.

# what's under the hood
Raycasts and state-machine sort of logic. Nothing special, just just like a notebook of snippets to use.
