package MichaelsMagic
{
	/**
	 * ...
	 * @author Skillcheese
	 */
	
	import Bezel.Bezel;
	import Bezel.GCFW.Events.EventTypes;
	import Bezel.GCFW.Events.IngameGemInfoPanelFormedEvent;
	import Bezel.GCFW.Events.IngameKeyDownEvent;
	import Bezel.Logger;
	import Bezel.Utils.Keybind;
	import Bezel.Utils.SettingManager;
	import MichaelsMagic.Automater;
	import MichaelsMagic.BuildingType;
	import MichaelsMagic.InfoPanelState;
	import com.giab.common.utils.NumberFormatter;
	import com.giab.games.gcfw.GV;
	import com.giab.games.gcfw.SB;
	import com.giab.games.gcfw.constants.ActionStatus;
	import com.giab.games.gcfw.constants.IngameStatus;
	import com.giab.games.gcfw.entity.Gem;
	import com.giab.games.gcfw.mcDyn.McInfoPanel;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.filters.GlowFilter;
	import flash.utils.Timer;

	// We extend MovieClip so that flash.display.Loader accepts our class
	// The loader also requires a parameterless constructor (AFAIK), so we also have a .Bind method to bind our class to the game
	public class GCFWMichaelsMagic
	{
		public const GAME_VERSION:String = "1.2.1a";
		
		// Mod loader object
		internal static var bezel:Bezel;
		
		internal static var logger:Logger;

		private var infoPanelState:int;

		private var settings:SettingManager;

		internal static var myStorage:File = File.applicationStorageDirectory.resolvePath("MichaelsMagic/");
		
		private var automaters:Array = new Array();
		private var automatersEnabled:Boolean = false;
		private var renderingAutomaters:Boolean = false;
		private var automaterDelay:int = 125;
		private var automatersIndex:int = 0;
		private var replaceMode:Boolean = false;
		
		// Parameterless constructor for flash.display.Loader
		public function GCFWMichaelsMagic()
		{
			super();
		}
		
		// This method binds the class to the game's objects
		public function bind(modLoader:Bezel, gameObjects:Object) : void
		{
			bezel = modLoader;
			logger = bezel.getLogger("MichaelsMagic");

			if (!myStorage.exists)
			{
				myStorage.createDirectory();
			}

			bezel.keybindManager.registerHotkey("MichaelsMagic: Spawn Automator", new Keybind("k"));
			bezel.keybindManager.registerHotkey("MichaelsMagic: Toggle Automators", new Keybind("j"));
			bezel.keybindManager.registerHotkey("MichaelsMagic: Toggle Replace/Upgrade Mode", new Keybind("alt+j"));
			this.infoPanelState = InfoPanelState.MICHAELSMAGIC;
			
			addEventListeners();
			
			logger.log("MichaelsMagic", "MichaelsMagic initialized!");
		}
		
		private function saveSlot(slot:int): void
		{
			var slotFile:File = myStorage.resolvePath("MichaelsMagic_slot" + slot + ".json");
			var slotStream:FileStream = new FileStream();
			var slotObject:Object = null;
			var slotJSON:String = null;
			
			slotObject = createSaveSlotFile();
			slotJSON = JSON.stringify(slotObject, null, 2);
			slotStream.open(slotFile, FileMode.WRITE);
			slotStream.writeUTFBytes(slotJSON);
			slotStream.close();
		}
		
		private function createSaveSlotFile(): Object
		{
			var r:Object = new Object();
			var array:Array = new Array();
			for (var i:int = 0; i < automaters.length; i++)
			{
				array.push({"x":automaters[i].x, "y":automaters[i].y});
			}
			r.array = array;
			return r;
		}

		private function loadSlot(slot:int): void
		{
			var slotFile:File = myStorage.resolvePath("MichaelsMagic_slot" + slot + ".json");
			var slotStream:FileStream = new FileStream();
			var slotObject:Object = null;
			var slotJSON:String = null;

			if(slotFile.exists)
			{
				try
				{
					slotStream.open(slotFile, FileMode.READ);
					slotJSON = slotStream.readUTFBytes(slotStream.bytesAvailable);
					slotObject = JSON.parse(slotJSON);
					
					logger.log("LoadConfiguration", "Loaded slot!");
				}
				catch(error:Error)
				{
					logger.log("LoadConfiguration", "There was an error when loading an existing slot:");
					logger.log("LoadConfiguration", error.message);
				}
				slotStream.close();
			}
			else
			{
				
			}
			if (slotObject != null) 
			{
				if (slotObject.array != null)
				{
					automaters = new Array();
					for (var i:int = 0; i < slotObject.array.length; i++)
					{
						var automater:Automater = new Automater(GV.ingameCore, this);
						automater.x = slotObject.array[i].x;
						automater.y = slotObject.array[i].y;
						automaters.push(automater);
					}
				}
			}
		}
		
		private function spawnAutomaterOnMouse(): void
		{
			if(GV.ingameCore.actionStatus == ActionStatus.CAST_GEMBOMB_INITIATED)
			{
				GV.ingameCore.controller.deselectEverything(true,false);
			}
			try
			{
				// ACTIONSTATUS enums are sadly not available yet
				if(GV.ingameCore.actionStatus < 300 || GV.ingameCore.actionStatus >= 600)
				{
					var gem:Gem = GV.ingameCore.controller.getGemUnderPointer(false);
					if (gem != null)
					{
						var selectedBuilding:Object = null;
						if (GV.ingameCore.selectedTower != null)
						{
							selectedBuilding = GV.ingameCore.selectedTower;
						}
						else if (GV.ingameCore.selectedTrap != null)
						{
							selectedBuilding = GV.ingameCore.selectedTrap;
						}
						else if (GV.ingameCore.selectedAmplifier != null)
						{
							selectedBuilding = GV.ingameCore.selectedAmplifier;
						}
						else if (GV.ingameCore.selectedLantern != null)
						{
							selectedBuilding = GV.ingameCore.selectedLantern;
						}
						if (selectedBuilding != null)
						{
							var x:Number = Math.round(GV.main.cntScreens.cntIngame.root.mouseX);
							var y:Number = Math.round(GV.main.cntScreens.cntIngame.root.mouseY);
							
							var automater:Automater = new Automater(GV.ingameCore, this);
							var automaterX:Number = Math.floor((x - 50) / 28);
							var automaterY:Number = Math.floor((y - 8) / 28);
							
							automater.init(automaterX, automaterY);
							var alreadyExists:Boolean = false;
							for (var i:int = 0; i < automaters.length; i++)
							{
								var current:Automater = automaters[i];
								if (automater.checkEquals(current))
								{
									alreadyExists = true;
									automaters.splice(i, 1);
									break;
								}
							}
							if (alreadyExists)
							{
								showMessage("Destroying automater!");
							}
							else
							{
								showMessage("Creating Automater!");
								automaters.push(automater); 
								if (!renderingAutomaters)
								{
									renderAutomaters();
									updateAutomaters();
								}
							}
						}
					}
					else
					{
						SB.playSound("sndalert");
						showMessage("No gem in structure under cursor");
						return;
					}
				}
			}
			catch(error:Error)
			{
				// TODO handle this exception wrt the gem
				logger.log("CastCombineOnMouse", "Caught an exception!");
				logger.log("CastCombineOnMouse", error.message);
				SB.playSound("sndalert");
				showMessage("Caught an exception!");
				return;
			}
		}
		
		private function renderAutomaters(): void
		{
			renderingAutomaters = true;
			if (GV.ingameCore.ingameStatus == IngameStatus.PLAYING || GV.ingameCore.ingameStatus == IngameStatus.PLAYING_SHRINE_ACTIVE)
			{
				for each(var automater:Automater in automaters)
				{
					if (automater != null)
					{
						if (!automater.isDestroyed)
						{
							GV.vfxEngine.createFloatingText4(automater.pX + 60, automater.pY - 8, "*", 16711696, 16, "center", 0, 0, 0, 0, 8, 0, 125);
						}
					}
				}
			}
			var timer:Timer = new Timer(250, 1);
			var func:Function = function(e:Event): void {renderAutomaters(); };
			timer.addEventListener(TimerEvent.TIMER, func);
			timer.start();
		}
		
		private function updateAutomaters(): void
		{
			if (GV.ingameCore.ingameStatus != IngameStatus.PLAYING && GV.ingameCore.ingameStatus != IngameStatus.PLAYING_SHRINE_ACTIVE)
			{
				automaters = new Array();
				automatersEnabled = false;
			}
			automaters = automaters.filter(filterAutomaters);
			var finished:Boolean = automaters.length == 0;
			while (!finished)
			{
				if (replaceMode || !automatersEnabled)
				{
					finished = true;
				}
				automaters.sort(sortAutomaters);
				for each(var automater:Automater in automaters)
				{
					if (automater != null)
					{
						if (!automater.isDestroyed)
						{
							if (GV.ingameCore.getMana() < automater.getGemCost() + GV.ingameCore.gemCombiningManaCost.g())
							{
								finished = true;
								break;
							}
							automater.updateAutomater(replaceMode, automatersEnabled);
							
						}
						else
						{
							showMessage("destroyed automater in array");
						}
					}
				}
			}
			var timer:Timer = new Timer(automaterDelay, 1);
			var func:Function = function(e:Event): void {updateAutomaters(); };
			timer.addEventListener(TimerEvent.TIMER, func);
			timer.start();
		}
		
		private function sortAutomaters(a:Automater, b:Automater): int
		{
			var aIsAmp: Boolean = a.buildingType == BuildingType.AMPLIFIER;
			var bIsAmp: Boolean = b.buildingType == BuildingType.AMPLIFIER;
			var aCost: Number = a.getGemCost();
			var bCost: Number = b.getGemCost();
			if (aCost == -1 || bCost == -1) 
			{
				return 0;
			}
			var specRatio: Number = 0.15 + GV.ingameCore.skillEffectiveValues[19][1].g(); //SkillId.AMPLIFIERS = 19
			var aDesiredCostRatio:Number = Math.pow(specRatio * a.numNeighbors, 1.868); // [1 / (1 - log(1.38) / log(2))]
			var bDesiredCostRatio:Number = Math.pow(specRatio * b.numNeighbors, 1.868); // [1 / (1 - log(1.38) / log(2))]
			var aTotal:Number = aIsAmp ? aDesiredCostRatio : 1;
			var bTotal:Number = bIsAmp ? bDesiredCostRatio : 1;
			aTotal *= bCost; // switched because we want the b cost to make it upgrade a sooner
			bTotal *= aCost; // if aCost is higher we want it to upgrade b because b is worse gem
			return Math.max(Math.min(bTotal - aTotal, 1), -1);
		}
		
		private function filterAutomaters(element:*, index:int, arr:Array): Boolean
		{
			if (element is Automater)
			{
				if (Automater(element).isDestroyed)
				{
					return false;
				}
				else
				{
					return true;
				}
			}
			return false;
		}

		public function showMessage(message:String) :void
		{
			GV.vfxEngine.createFloatingText4(GV.main.mouseX, GV.main.mouseY < 60?Number(GV.main.mouseY + 30):Number(GV.main.mouseY - 20), message, 16768392, 12, "center", Math.random() * 3 - 1.5, -4 - Math.random() * 3, 0, 0.55, 12, 0, 1000);
		}
		
		// Either:
		// 1 - Processes the hotkey if it's bound to a Gemsmith function
		// 2 - Substitutes the KeyCode from Gemsmith_config.json
		// Then it either lets the base game handler to run (so it then fires the function with the substituted KeyCode)
		// or stops the base game's handler
		private function eh_interceptKeyboardEvent_MichaelsMagic(event: IngameKeyDownEvent): void
		{
			if (bezel.keybindManager.getHotkeyValue("MichaelsMagic: Spawn Automator").matches(event))
			{
				spawnAutomaterOnMouse();
				event.eventArgs.continueDefault = false;
			}
			else if (bezel.keybindManager.getHotkeyValue("MichaelsMagic: Toggle Automators").matches(event))
			{
				automatersEnabled = !automatersEnabled;
				showMessage(automatersEnabled ? "Automaters turned on!" : "Automaters turned off!");
				event.eventArgs.continueDefault = false;
			}
			else if (bezel.keybindManager.getHotkeyValue("MichaelsMagic: Toggle Replace/Upgrade Mode").matches(event))
			{
				replaceMode = !replaceMode;
				showMessage(replaceMode ? "Automaters now in replace mode!" : "Automaters now in upgrade mode!");
				event.eventArgs.continueDefault = false;
			}
			else if (bezel.keybindManager.getHotkeyValue("Show/hide info panels").matches(event))
			{
				if (this.infoPanelState == InfoPanelState.HIDDEN)
				{
					this.infoPanelState = InfoPanelState.BASEGAME;
				}
				else if (this.infoPanelState == InfoPanelState.BASEGAME)
				{
					this.infoPanelState = InfoPanelState.MICHAELSMAGIC;
					event.eventArgs.continueDefault = false;
				}
				else
				{
					this.infoPanelState = InfoPanelState.HIDDEN;
				}
			}
		}
		
		private function eh_ingameGemInfoPanelFormed(event:IngameGemInfoPanelFormedEvent): void
		{
			var vIp:McInfoPanel = event.eventArgs.infoPanel as McInfoPanel;
			var gem:Gem = event.eventArgs.gem as Gem;
			if (this.infoPanelState == InfoPanelState.MICHAELSMAGIC)
			{
				vIp.addExtraHeight(8);
				vIp.addSeparator(0);
				vIp.addTextfield(1015015, "Michael's Magic", true, 13, [new GlowFilter(0, 1, 3, 6), new GlowFilter(11056320, 0.28, 25, 12)]);
				vIp.addTextfield(1015015, replaceMode ? "Replace mode" : "Upgrade mode", true, 8);
				vIp.addTextfield(1015015, automatersEnabled ? "Automaters enabled" : "Automaters disabled", true, 8);
				var str:String = "";
				str = automatersEnabled ? "j to disable automaters" : "j to enable automaters";
				vIp.addTextfield(10526880, str, true, 7);
				str = "k to create or destroy an automater!";
				vIp.addTextfield(10526880, str, true, 7);
				if (gem != null && GV.ingameCore.inventorySlots[2] != null)
				{
					if (gem == GV.ingameCore.inventorySlots[2])
					{
						str = replaceMode ? "alt + j to switch to upgrade mode" : "alt + j to switch to replace mode with this gem";
						vIp.addTextfield(10526880, str, true, 7);
					}
				}
				var vDmg:Number = Math.round(gem.sd5_EnhancedOrTrapOrLantern.damageMin.g() + 0.5 * (gem.sd5_EnhancedOrTrapOrLantern.damageMax.g() - gem.sd5_EnhancedOrTrapOrLantern.damageMin.g()));
				vDmg = vDmg * (1 + gem.sd5_EnhancedOrTrapOrLantern.critHitMultiplier.g());
				str = "Expected Damage: " + NumberFormatter.format(vDmg);
				vIp.addTextfield(16777215, str, true, 9);
				vIp.addExtraHeight(6);
			}
		}
		
		public function prettyVersion(): String
		{
			return 'v' + MichaelsMagicMod.MM_VERSION + ' for ' + GAME_VERSION;
		}
		
		private function addEventListeners(): void
		{
			bezel.addEventListener(EventTypes.INGAME_GEM_INFO_PANEL_FORMED, eh_ingameGemInfoPanelFormed);
			bezel.addEventListener(EventTypes.INGAME_KEY_DOWN, eh_interceptKeyboardEvent_MichaelsMagic);
		}
		
		public function unload(): void
		{
			removeEventListeners();
			bezel = null;
			logger = null;
		}
		
		private function removeEventListeners(): void
		{
			bezel.removeEventListener("ingameGemInfoPanelFormed", eh_ingameGemInfoPanelFormed);
			bezel.removeEventListener("ingameKeyDown", eh_interceptKeyboardEvent_MichaelsMagic);
		}
		
    }
}
