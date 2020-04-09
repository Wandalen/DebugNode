var ChildProcess = require( 'child_process' );
var path = require( 'path' );

// debugger
let o =  { stdio : 'pipe', env : { var : 1 } }
let args = [];
let execPath = path.join( __dirname, 'Child.js' );

var child = ChildProcess.fork( execPath, args, o )

child.stdout.on( 'data', data => 
{ 
  console.log( data.toString() ) 
})

console.log( 'Index.js executed' )
