
let _ = require( 'wTools' );
_.include( 'wProcess' );

_.process.startNjs({ execPath : _.path.nativize( _.path.join( __dirname, 'Sample2.s' ) ), mode : 'spawn', stdio : 'inherit' })
.thenKeep( () =>
{
  return null;
})
