
var _ = require( 'wprocess' );

debugger
_.process.startNode({ execPath : _.path.join( __dirname, 'Sample2.js' ), mode : 'spawn', stdio : 'inherit' })
.thenKeep( () =>
{
  debugger
  return null;
})
