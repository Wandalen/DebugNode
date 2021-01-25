## How to use debugnode utility

### How to install:
 
```npm -g install debugnode```

### How to run:

```debugnode [script path] [arguments]```

```debugnode .run [script path] [arguments]```

Example:

```debugnode sample/trivial/Sample.s arg1 arg2 arg3```

*Script path can be absolute or relative to current working directory.*

*Script arguments are optional*

### How to get help:

```debugnode .help```

### How to restart debugging:

Focus on any debugger window hit `F5`. Utility will close debugger windows of child processes created during execution and restart debugging of main script file.


### How to know which script file is debugged

The title of debugger window contains path to debugged script file.