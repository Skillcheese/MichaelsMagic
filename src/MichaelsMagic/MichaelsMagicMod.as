package MichaelsMagic
{
	import Bezel.Bezel;
	import Bezel.BezelMod;
	import flash.display.MovieClip;

    /**
     * ...
     * @author Chris
     */
    public class MichaelsMagicMod extends MovieClip implements BezelMod
    {
        public static const MM_VERSION:String = "1.3";
        public function get VERSION():String { return MM_VERSION; }
		public function get BEZEL_VERSION():String { return "2.0.0"; }
		public function get MOD_NAME():String { return "MichaelsMagic"; }

        private var mm:GCFWMichaelsMagic;

        public function bind(bezel:Bezel, gameObjects:Object):void
        {
            this.mm = new GCFWMichaelsMagic();
            mm.bind(bezel, gameObjects);
        }

        public function unload():void
        {
            mm.unload();
        }
    }
}
