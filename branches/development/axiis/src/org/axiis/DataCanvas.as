package org.axiis
{
	import com.degrafa.IGeometryComposition;
	
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	
	import mx.core.IFactory;
	import mx.core.IToolTip;
	import mx.core.UIComponent;
	import mx.managers.ToolTipManager;
	
	import org.axiis.core.AxiisSprite;
	import org.axiis.core.ILayout;
	import org.axiis.events.LayoutEvent;
	
	
	public class DataCanvas extends UIComponent
	{
		[Bindable]
		public var fills:Array = [];
		
		[Bindable]
		public var strokes:Array = [];
		
		[Bindable]
		public var palettes:Array = [];
		
		public function DataCanvas()
		{
			super();
		}
		
		
		public var labelFunction:Function;
		
		public var dataFunction:Function;
		
		public var showDataTips:Boolean = true;
		
		public var toolTipClass:IFactory;
		
		public var hitRadius:Number = 10;
		
		private var toolTips:Array = [];
		
		[Bindable(event="dataProviderChange")]
		public function set dataProvider(value:Object):void
		{
			if(value != _dataProvider)
			{
				_dataProvider = value;
				invalidateDisplayList();
				dispatchEvent(new Event("dataProviderChange"));
			}
		}
		public function get dataProvider():Object
		{
			return _dataProvider;
		}
		private var _dataProvider:Object;
			
		
		//TODO: I think we might consider using ArrayCollections and some initCollection calls (look at how degrafa handles this)
		public var layouts:Array;
		
		public var backgroundGeometries:Array;
		
		public var foregroundGeometries:Array;
		
		private var invalidatedLayouts:Array = [];
		
		private var _background:AxiisSprite;
		
		private var _foreground:AxiisSprite;
		
		override protected function createChildren():void
		{
			super.createChildren();
			
			_background=new AxiisSprite();
			addChild(_background);

			for each(var layout:ILayout in layouts)
			{
				layout.registerOwner(this);
				var sprite:Sprite = layout.getSprite(this);
				addChild(sprite);
				
				layout.addEventListener(LayoutEvent.INVALIDATE,handleLayoutInvalidate);
				if (layout.emitDataTips)
					sprite.addEventListener(MouseEvent.MOUSE_OVER,onItemMouseOver);
				sprite.addEventListener(MouseEvent.CLICK,onItemMouseClick);
				sprite.addEventListener(MouseEvent.DOUBLE_CLICK,onItemMouseDoubleClick);
				sprite.addEventListener(MouseEvent.MOUSE_OUT,onItemMouseOut);
				sprite.addEventListener(MouseEvent.MOUSE_DOWN,onItemMouseDown);
				sprite.addEventListener(MouseEvent.MOUSE_UP,onItemMouseUp);
		
				invalidatedLayouts.push(layout);
			}
			
			_foreground=new AxiisSprite();
			addChild(_foreground);
		}
		
		/**
		 * TODO implement measure
		 * 
		 * For now we can just set some defaults
		 */
		override protected function measure():void
		{
			super.measure();
			measuredWidth = 400;
			measuredHeight = 400;
		}
		
		private var _invalidated:Boolean=false;
		
		override public function invalidateDisplayList():void
		{
			if (!_invalidated)
				invalidateAllLayouts();
			
			_invalidated = true;
		} 
		
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth,unscaledHeight);
			
			
			
			_background.graphics.clear();
			
			for each (var bg:Object in backgroundGeometries) {
				if (bg is ILayout) {
					ILayout(bg).render(_background)
				}
				else if (bg is IGeometryComposition) {
					bg.preDraw();
					bg.draw(_background.graphics,bg.bounds);
				}
			}
			
			while(invalidatedLayouts.length > 0)
			{
				var layout:ILayout = ILayout(invalidatedLayouts.pop());				
				layout.render();
			}
			
			_foreground.graphics.clear();
			for each (var fg:Object in foregroundGeometries) {
				if (fg is ILayout) {
					ILayout(fg).render(_foreground)
				}
				else if (fg is IGeometryComposition) {
					fg.preDraw();
					fg.draw(_foreground.graphics,fg.bounds);
				}
			}
			
			
			/* this.graphics.clear();
			this.graphics.beginFill(0xff,.1);
			this.graphics.drawRect(0,0,width,height);
			this.graphics.endFill(); */
			
			_invalidated = false;
		}
		
		protected function handleLayoutInvalidate(event:LayoutEvent):void
		{
			if(invalidatedLayouts.indexOf(event.layout) == -1)
			{
				invalidatedLayouts.push(event.layout);
				super.invalidateDisplayList();
			}
		}
		
		protected function invalidateAllLayouts():void
		{
			for each(var layout:ILayout in layouts)
			{
				invalidatedLayouts.push(layout);
			}
			super.invalidateDisplayList();
		}
		
		/****   ITEM EVENTS ****/
		public function onItemMouseOver(e:MouseEvent):void
		{
			var axiisSprite:AxiisSprite = e.target as AxiisSprite;
			if(!axiisSprite)
				return;
			
			if(axiisSprite.layout)
			{
				if(showDataTips && axiisSprite.layout.dataTipLabelFunction != null)
				{
					var hitSiblings:Array = getHitSiblings(axiisSprite);
					for each(var sibling:AxiisSprite in hitSiblings)
					{
						showToolTip(sibling);
					}
					if(doToolTipsOverlap())
						repositionToolTips();
				}
			}
		}
		
		public function onItemMouseOut(e:MouseEvent):void
		{
			var axiisSprite:AxiisSprite = e.target as AxiisSprite;
			if(!axiisSprite)
				return;
			
			while(toolTips.length > 0)
			{
				var tt:IToolTip = IToolTip(toolTips.pop());
				ToolTipManager.destroyToolTip(tt);
				tt = null;
			}	
		}
		
		public function onItemMouseDown(e:MouseEvent):void {
		}
		
		public function onItemMouseUp(e:MouseEvent):void {
		}

		public function onItemMouseClick(e:MouseEvent):void {
		}
		
		public function onItemMouseDoubleClick(e:MouseEvent):void {
		}
		
		private function getHitSiblings(axiisSprite:AxiisSprite):Array
		{
			var s:Sprite = new Sprite();
			s.graphics.clear();
			s.graphics.beginFill(0,0);
			s.graphics.drawCircle(mouseX,mouseY,hitRadius);
			s.graphics.endFill();
			addChild(s);
			
			var toReturn:Array = [];
			var siblings:Array = axiisSprite.layout.childSprites;
			for each(var sibling:AxiisSprite in siblings)
			{
				if(sibling.hitTestObject(s))
				{
					toReturn.push(sibling);
				}
			}
			
			removeChild(s);
			
			return toReturn;
		}
		
		private function showToolTip(axiisSprite:AxiisSprite):void
		{
			var text:String = axiisSprite.layout.dataTipLabelFunction.call(this,axiisSprite.data);
			if(text != null && text != "")
			{
				var tt:IToolTip = ToolTipManager.createToolTip(text,stage.mouseX + 10,stage.mouseY + 10);
				if(axiisSprite.layout.dataTipPositionFunction != null)
				{
					var position:Point = axiisSprite.layout.dataTipPositionFunction.call(this,axiisSprite,tt);
					tt.x = position.x;
					tt.y = position.y;
				}
				toolTips.push(tt);
			}
		}
		
		/**
		 * Reposition the tool tips by laying them out in four columns around the cursor.
		 * The first column starts down and to the right of the cursor, the second
		 * starts down and to the left, the third is above and to the left, and the
		 * last column starts above and to the right. Each column grows vertically
		 * away from the cursor.
		 * 
		 * This method needs to be adjusted to account for tool tips that end up offscreen.
		 */
		private function repositionToolTips():void
		{
			var startX:Number = stage.mouseX;
			var startY:Number = stage.mouseY;
			var gapX:Number = 10;
			var gapY:Number = 10;
			var offsetYs:Array = [0,0,0,0];
			for(var a:int = 0; a < toolTips.length; a++)
			{
				var tt:IToolTip = toolTips[a] as IToolTip;
				var offsetY:Number = offsetYs[a % 4];
				if(a % 4 == 0)
				{
					tt.x = startX + gapX;
					tt.y = startY + gapY + offsetY;
				}
				else if(a % 4 == 1)
				{
					tt.x = startX - gapX - tt.width;
					tt.y = startY + gapY + offsetY;
				}
				else if(a % 4 == 2)
				{
					tt.x = startX - gapX - tt.width;
					tt.y = startY - gapY - tt.height - offsetY;
				}
				else
				{
					tt.x = startX + gapX;
					tt.y = startY - gapY - tt.height - offsetY;
				}
				offsetYs[a % 4] += tt.height;
			}
		}
		
		private function doToolTipsOverlap():Boolean 	
		{
			if(toolTips.length < 1)
				return false;
				
			var toolTipsOverlap:Boolean = false;
			for(var a:int = 0; a < toolTips.length - 1; a++)
			{
				var toolTip1:IToolTip = toolTips[a];
				for(var b:int = a + 1; b < toolTips.length; b++)
				{
					var toolTip2:IToolTip = toolTips[b];
					if(toolTip1.hitTestObject(toolTip2 as DisplayObject))
						return true;
				}
			}
			return false;
		}
	}
}