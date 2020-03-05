package MichaelsMagic 
{
	import MichaelsMagic.MichaelsMagic;
	import flash.utils.getDefinitionByName;
	/**
	 * ...
	 * @author Skillcheese
	 */
	public class Automater 
	{
		
		public var x:Number;
		public var y:Number;
		public var pX:Number;
		public var pY:Number;
		public var isDestroyed:Boolean = false;
		private var core:Object = null;
		private var mm:Object = null;
		public var buildingType:int = -1;
		public var numNeighbors:int = 0;
		
		public function Automater(coreRef:Object, mmRef:Object) 
		{
			x = 0;
			y = 0;
			pX = 0;
			pY = 0;
			core = coreRef;
			mm = mmRef;
		}
		
		public function init(xx:Number, yy:Number): void
		{
			x = xx;
			y = yy;
			buildingType = getBuildingType();
			if (buildingType == BuildingType.AMPLIFIER)
			{
				numNeighbors = getNumNeighbors();
			}
			var building:Object = core.buildingAreaMatrix[y][x];
			if (building != null)
			{
				pX = building.x;
				pY = building.y;
			}
		}
		
		public function checkEquals(other:Automater): Boolean
		{
			if (this.x == other.x && this.y == other.y)
			{
				return true;
			}
			else if (core.buildingAreaMatrix[other.y][other.x] == core.buildingAreaMatrix[y][x])
			{
				return true;
			}
			return false;
		}
		
		public function updateAutomater(replace:Boolean, actuallyUpdate:Boolean): void
		{
			if (isDestroyed)
			{
				return;
			}
			if (buildingType == -1)
			{
				mm.showMessage("building type == -1");
				return;
			}
			var building:Object = core.buildingAreaMatrix[y][x];
			if (building != null)
			{
				var buildingGem:Object = building.insertedGem;
				if (buildingGem != null)
				{
					if (!actuallyUpdate)
					{
						return;
					}
					if (replace)
					{
						var gem:Object = core.inventorySlots[2];
						if (gem != null)
						{
							if (areGemsDifferent(buildingGem, gem)) //check if gems are different
							{
								if (core.getMana() >= gem.cost.g())
								{
									var numSlot:Number = core.spellCaster.castCloneGem(gem);
									if (numSlot == -1)
									{
										mm.showMessage("You need at least 1 open inventory slot!");
									}
									else
									{
										var gemToInsert:Object = core.inventorySlots[numSlot];
										core.spellCaster.castRefundGem(buildingGem);
										if (core.gems.indexOf(buildingGem != -1))
										{
											core.gems.splice(core.gems.indexOf(buildingGem), 1);
										}
										core.inventorySlots[numSlot] = null;
										building.insertGem(gemToInsert);
									}
									
								}
							}
						}
					}
					else
					{
						if (core.getMana() >= buildingGem.cost.g() + core.gemCombiningManaCost.g())
						{
							core.changeMana( -buildingGem.cost.g(), false, true);
							core.spellCaster.castCombineGemsFromBuildingToBuilding(building, building, false);
						}
						else
						{
							//mm.showMessage("Not enough mana or gem is too high grade!");
						}
					}
				}
				else 
				{
					mm.showMessage("No gem in building, removing automater!");
					isDestroyed = true;
				}
			}
			else
			{
				mm.showMessage("building has been destroyed, removing automater!");
				isDestroyed = true;
			}
		}
		
		private function areGemsDifferent(gemA:Object, gemB:Object): Boolean
		{
			if (gemA.cost.g() != gemB.cost.g() || gemA.grade.g() != gemB.grade.g())
			{
				return true;
			}
			if (gemA.manaValuesByComponent.length < 6 || gemB.manaValuesByComponent.length < 6)
			{
				return false;
			}
			for (var i:int = 0; i < 6; i++)
			{
				if (gemA.manaValuesByComponent[i].g() != gemB.manaValuesByComponent[i].g())
				{
					return true;
				}
			}
			return false;
		}
		
		public function getGemGrade(): Number
		{
			var building:Object = core.buildingAreaMatrix[y][x];
			if (building != null)
			{
				if (building.insertedGem != null)
				{
					return building.insertedGem.grade.g();
				}
			}
			return -1;
		}
		
		public function getGemCost(): Number
		{
			var building:Object = core.buildingAreaMatrix[y][x];
			if (building != null && buildingType != -1)
			{
				if (building.insertedGem != null)
				{
					return building.insertedGem.cost.g();
				}
			}
			return -1;
		}
		
		private function getBuildingType(): int
		{
			var building:Object = core.buildingAreaMatrix[y][x];
			return getTypeOfBuilding(building);
		}
		
		private function getNumNeighbors(): int
		{
			var neighbors:Array = new Array();
			var building:Object = core.buildingAreaMatrix[y][x];
			for (var ix:int = -2; ix <= 2; ix++)
			{
				for (var iy:int = -2; iy <= 2; iy++)
				{
					var xx:Number = x + ix;
					var yy:Number = y + iy;
					if (xx < 0 || yy < 0 || xx > 59 || yy > 37)
					{
						continue;
					}
					var buildingOther:Object = core.buildingAreaMatrix[y + iy][x + ix];
					if (buildingOther != null && buildingOther != null && buildingOther != building)
					{
						if (getTypeOfBuilding(buildingOther) == BuildingType.TRAP)
						{
							var shouldAdd:Boolean = true;
							for each(var neighbor:Object in neighbors)
							{
								if (neighbor == buildingOther)
								{
									shouldAdd = false;
								}
							}
							if (shouldAdd)
							{
								neighbors.push(buildingOther);
							}
						}
					}
				}
			}
			return neighbors.length;
		}
		
		private function getTypeOfBuilding(building:Object): int
		{
			if (building != null)
			{
				var Trap:Class = getDefinitionByName("com.giab.games.gcfw.steam.entity.Trap") as Class;
				var Tower:Class = getDefinitionByName("com.giab.games.gcfw.steam.entity.Tower") as Class;
				var Amplifier:Class = getDefinitionByName("com.giab.games.gcfw.steam.entity.Amplifier") as Class;
				var Lantern:Class = getDefinitionByName("com.giab.games.gcfw.steam.entity.Lantern") as Class;
				if (building is Trap)
				{
					return BuildingType.TRAP;
				}
				if (building is Tower)
				{
					return BuildingType.TOWER;
				}
				if (building is Amplifier)
				{
					return BuildingType.AMPLIFIER;
				}
				if (building is Lantern)
				{
					return BuildingType.LANTERN;
				}
			}
			return -1;
		}
	}

}