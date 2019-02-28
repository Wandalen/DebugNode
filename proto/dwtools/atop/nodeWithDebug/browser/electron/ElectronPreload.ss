let ansi = require ('ansicolor')

ansi.rgb =
{
    black:        [0,     0,   0],
    darkGray:     [100, 100, 100],
    lightGray:    [200, 200, 200],
    white:        [255, 255, 255],

    red:          [255,   0,   0],
    lightRed:     [255,  51,   0],

    green:        [0,   255,   0],
    lightGreen:   [51,  204,  51],

    yellow:       [255, 153,  51],
    lightYellow:  [255, 255,  0],

    blue:         [0,     0, 255],
    lightBlue:    [26,  140, 255],

    magenta:      [204,   0, 204],
    lightMagenta: [255,   0, 255],

    cyan:         [0,   204, 255],
    lightCyan:    [0,   255, 255],
}

window.onload = function()
{
    let original = SDK.consoleModel.addMessage;
    SDK.consoleModel.addMessage = function addMessage( message )
    {
        let parsed = ansi.parse( message.messageText );
        message.parameters = parsed.asChromeConsoleLogArguments;
        message.messageText = message.parameters[ 0 ];
        original.call( SDK.consoleModel, message );
    }
}
