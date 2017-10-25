if( typeof module !== "undefined" )
{
  require( 'wTools' );
  require( 'wConsequence' );
	var _ = wTools;
}

debugger

var args = _.appArgs();

_.timeOut( 2000, () => console.log( args ) )

/*
	How to run:

	node Inspect.ss sample/Sample.js args : a b c
	or
	winspect sample/Sample.js args : a b c
*/