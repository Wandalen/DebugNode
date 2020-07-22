
let _ = require( 'wprocess' );

debugger
_.process.startNode({ execPath : _.path.join( __dirname, 'Sample2.s' ), mode : 'spawn', stdio : 'inherit' })
.thenKeep( () =>
{
  debugger
  return null;
})
