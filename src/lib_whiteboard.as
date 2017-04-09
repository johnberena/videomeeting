// ActionScript file

/*
* 
* This source code file is part of the WebELS Software System.
* WebELS is under the WebELS Software License Agreement. 
* 
*        ***Preamble of WebELS Software License Agreement***
*
* This Software License Agreement (hereinafter referred to as License) 
* is a legal agreement between the User (either an individual or an entity, 
* who will be referred to in this License as User) and the WebELS Project 
* (represented by the project leader and patent owner, and will be referred 
* to in this License as WebELS) of National Institute of Informatics for 
* the use of WebELS Software (Software). By downloading, installing, copying, 
* modifying, redistributing, or using the Software, the User is agreeing to 
* be bound by the terms and conditions of this License. If you do not agree 
* to the terms and conditions of this License, do not download, install, copy, 
* modify, redistribute or use in any way as a whole or any part of the Software.
*
* For more details, see the WebELS Software License Agreement in 
* license.txt in root directory of this package. If not found, 
* see <http://webels.ex.nii.ac.jp/service/download/license/>
*
* Should you have any questions concerning this License, or if you desire 
* to contact WebELS Project Leader for any reason, please write to:
* 
* Prof. Haruki Ueno, PhD
* Professor Emeritus, National Institute of Informatics
* 2-1-2 Hitotsubashi, Chiyodaku
* 101-8430 Tokyo,Japan
* Tel. +81-3-4212-2630
* E-mail: ueno@nii.ac.jp
* 
* WebELS Project of the National Institute of Informatics (NII), Tokyo, Japan
* http://webels.ex.nii.ac.jp/
* Copyright © 2012 by WebELS Project of NII. All rights reserved.
*
*/

include "lib_chairman.as";

import com.lorentz.SVG.data.text.SVGTextToDraw;
import com.lorentz.SVG.display.SVGDocument;
import com.lorentz.SVG.display.base.SVGElement;
import com.lorentz.SVG.events.SVGEvent;
import com.lorentz.SVG.text.FTESVGTextDrawer;
import com.lorentz.SVG.text.TLFSVGTextDrawer;
import com.lorentz.SVG.text.TextFieldSVGTextDrawer;
import com.lorentz.SVG.utils.DisplayUtils;
import com.lorentz.processing.ProcessExecutor;

import flash.display.Loader;
import flash.display.Stage;
import flash.display.StageDisplayState;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.events.NetStatusEvent;
import flash.events.TimerEvent;
import flash.external.ExternalInterface;
import flash.net.FileReference;
import flash.net.NetConnection;
import flash.net.NetStream;
import flash.net.Responder;
import flash.net.SharedObject;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.net.URLRequestHeader;
import flash.net.URLRequestMethod;
import flash.net.URLVariables;
import flash.utils.Timer;

import mx.collections.ArrayCollection;
import mx.controls.Alert;
import mx.controls.Image;
import mx.controls.VSlider;
import mx.events.DragEvent;
import mx.events.FlexEvent;
import mx.events.ListEvent;
import mx.events.PropertyChangeEvent;
import mx.events.ResizeEvent;
import mx.events.ScrollEvent;
import mx.events.SliderEvent;
import mx.events.VideoEvent;
import mx.graphics.ImageSnapshot;
import mx.managers.CursorManager;
import mx.managers.PopUpManager;

import spark.components.Group;
import spark.components.TitleWindow;


private var WBDEBUG:Boolean = false;

[Embed(source="assets/play-video-24x24.png")] 
[Bindable] private var play_video:Class;
[Embed(source="assets/pause-video-24x24.png")]  
[Bindable] private var pause_video:Class;
[Embed(source="assets/replay-video-24x24.png")]  
[Bindable] private var replay_video:Class;
[Embed(source="assets/wb-speaker-on-24x24.png")]  
[Bindable] private var wb_speaker_on:Class;
[Embed(source="assets/wb-speaker-off-24x24.png")]  
[Bindable] private var wb_speaker_off:Class;
[Embed(source="assets/text-editor-32x32.png")]  
[Bindable] private var text_editor:Class;
[Embed(source="assets/slide-presentation-32x32.png")]  
[Bindable] private var slide_presentation:Class;

[Bindable]
private var wb_box:whiteboard = null;
private var is_wb_connected:Boolean = false;	// flag for checking a connection

//------------------Whiteborad Function---------------------------------------
private var drawing_layer:Group; 
private var bg_color_picker:ColorPicker; 
private var bg_alpha_slider:VSlider;

private var tool_box_width:int = 50; 
private var bg_color:uint = 0xFFFFFF;
private var bg_index:int; 
private var zoom_value:Number = 0;
private var zoom_value_max:Number = 3;
private var width_value:Number = 0;
private var height_value:Number = 0;
private var scrollbar_x:Number = 0;
private var scrollbar_y:Number = 0;

public var whiteboard_w_original:Number = 0;
public var whiteboard_h_original:Number = 0; 

private var is_presenter:Boolean = false;  //for whiteboard operation
private var is_presenter_reconnect:Boolean = false; //for keeping presentor status at auto-reconnection
private var is_offline_mode:Boolean = false; //for whiteboard operation
private var is_scrolling_viewport:Boolean = false; 
private var mouseMoveY:Number = 0;
private var mouseMoveX:Number = 0;
private var newScrollPosX:Number;
private var newScrollPosY:Number;

private var file_conversion_output:String = "jpg"; //for adding new files in whiteboard panel
private var old_slide_type:String = null;

[Bindable]
private var image_files:ArrayCollection;
[Bindable]
private var contentsList:ArrayCollection = new ArrayCollection;
[Bindable] 
private var penSizes:ArrayCollection = new ArrayCollection([ 
	{label:"1", data:1}, 
	{label:"2", data:2}, 
	{label:"3", data:3}, 
	{label:"4", data:4}, 
	{label:"5", data:5},
	{label:"8", data:8},
	{label:"10", data:10},
	{label:"12", data:12},
	{label:"15", data:15}, 
	{label:"20", data:20}, 
	{label:"25", data:25},
	{label:"30", data:30},
	{label:"35", data:35},
	{label:"40", data:40},
	{label:"45", data:45}]); 

[Bindable]
private var simpleDP:Array = ['0x000000', '0xFF0000', '0xFF8800',
	'0xFFFF00', '0x88FF00', '0x00FF00', '0x00FF88', '0x00FFFF', 
	'0x0088FF', '0x0000FF', '0x8800FF', '0xFF00FF', '0xFFFFFF'];

private var current_layer:Group; 
private var isDrawStarted:Boolean = false; 
private var draw_x:Number; 
private var draw_y:Number;
private var textBoolean:Boolean; 
private var slideBoolean:Boolean;
private var penBoolean:Boolean;
private var eraserBoolean:Boolean;
private var cursorBoolean:Boolean;
private var dragBoolean:Boolean;
private var sharedColor:uint;
private var isA4Zoom:Boolean = false;

private var file:FileReference;
private var request:URLRequest;
private var predictLoader:URLLoader;
private var predictRequest:URLRequest;
private var preDownloadSlideCount:int = 0;
private var preDownloadThumbCount:int = 0;

private var old_page_num:Number = 1; //Slide Page Number (old)
private var present_page_num:Number = 1; //Slide Page Number (Present)
private var last_page_num:Number = 1; //Slide Page Number (Last)

private var current_presenter:Number = 0; //current presenter's clientID; 0 means no presenter

private var pgTimer:Timer = null;
private var pgAlert:Alert;

private var syncScrollInterval:uint = 0;  // update interval for scroll bar position 

/* for SVG Image */
private var svgDocument:SVGDocument;

private var boundsHeight:Number;
private var boundsWidth:Number;
private var scale:Number;

/* For Slide Embedded Video */
private var slidevideo:NetStream = null;
private var is_play:Boolean = false;
private var is_wb_speaker:Boolean = true;
private var is_first_play:Boolean = true;
private var is_first_metadata:Boolean = true; // to get only the first metadata (second metadata values are undefined)

private var video_timer:Timer;
private var video_pause_timer:Timer;
private const PLAYHEAD_UPDATE_INTERVAL_MS:uint = 10;//ms
private var video_duration:int;
private var video_width:Number;
private var video_height:Number;
private var VIDEO_BUFFER_TIME:Number = 1;  // seconds
private var wb_video_st:SoundTransform = new SoundTransform();

//----------------------------------------------------------------------------
private function whiteboard_init(wb:whiteboard): void {
	WBDEBUG = DEBUG;

	myWbDebug("whiteboard_init");
	
	wb_box = wb;
	
	resetWhiteboard();
	
	// ------------------------------------- 
	// Event   
	wb_box.wb_viewport.addEventListener(MouseEvent.MOUSE_DOWN, startScrollingImg);
	wb_box.wb_viewport.addEventListener(MouseEvent.MOUSE_MOVE, scrollingImg);
	wb_box.wb_viewport.addEventListener(MouseEvent.MOUSE_UP, stopScrollingImg);
	wb_box.chairman.addEventListener(Event.CHANGE, chairman_change); 
	wb_box.sort_date.addEventListener(Event.CHANGE, sortOption);
	wb_box.sort_title.addEventListener(Event.CHANGE, sortOption);	
	wb_box.presentor_action.addEventListener(Event.CHANGE, presenter_change); 
	wb_box.offline_mode.addEventListener(Event.CHANGE, offlineMode_change); 
	wb_box.function_mode_btn.addEventListener(FlexEvent.BUTTON_DOWN, modeToggle);
	wb_box.pen_btn.addEventListener(FlexEvent.BUTTON_DOWN, drawMode);
	wb_box.cursor_btn.addEventListener(FlexEvent.BUTTON_DOWN, cursorMode);
	wb_box.eraser_btn.addEventListener(FlexEvent.BUTTON_DOWN, eraseMode);
	wb_box.dragging.addEventListener(FlexEvent.BUTTON_DOWN, dragMode);
	wb_box.clear_btn.addEventListener(FlexEvent.BUTTON_DOWN, clearDrawing);	
	//wb_box.text_btn.addEventListener(FlexEvent.BUTTON_DOWN, textAnnotationFunc);	
	//	wb_box.expand_btn.addEventListener(FlexEvent.BUTTON_DOWN, expand);
	//	wb_box.expandw_btn.addEventListener(FlexEvent.BUTTON_DOWN, expandw);
	//	wb_box.depand_btn.addEventListener(FlexEvent.BUTTON_DOWN, depand);
	//	wb_box.depandw_btn.addEventListener(FlexEvent.BUTTON_DOWN, depandw);
	wb_box.zoomOut_btn.addEventListener(FlexEvent.BUTTON_DOWN, zoomOut);
	wb_box.zoomIn_btn.addEventListener(FlexEvent.BUTTON_DOWN, zoomIn);
	wb_box.zoomFit_btn.addEventListener(FlexEvent.BUTTON_DOWN, zoomFit);
	wb_box.zoomA4_btn.addEventListener(FlexEvent.BUTTON_DOWN, zoomA4);
	wb_box.hidelist_btn.addEventListener(FlexEvent.BUTTON_DOWN, toggleSlideTitle);
	wb_box.next_page.addEventListener(FlexEvent.BUTTON_DOWN, goNext);
	wb_box.previous_page.addEventListener(FlexEvent.BUTTON_DOWN, goPrevious);
	wb_box.first_page.addEventListener(FlexEvent.BUTTON_DOWN, goFirst); 
	wb_box.end_page.addEventListener(FlexEvent.BUTTON_DOWN, goLast);
	wb_box.next_page2.addEventListener(FlexEvent.BUTTON_DOWN, goNext);
	wb_box.previous_page2.addEventListener(FlexEvent.BUTTON_DOWN, goPrevious);
	wb_box.first_page2.addEventListener(FlexEvent.BUTTON_DOWN, goFirst);
	wb_box.end_page2.addEventListener(FlexEvent.BUTTON_DOWN, goLast);
	wb_box.file_upload.addEventListener(FlexEvent.BUTTON_DOWN, selectFileStart);
	wb_box.add_slide.addEventListener(FlexEvent.BUTTON_DOWN, addBlankPage);
	wb_box.remove_slide.addEventListener(FlexEvent.BUTTON_DOWN, confirmRemoveSlide);
	wb_box.remove_slides.addEventListener(FlexEvent.BUTTON_DOWN, confirmRemoveAllSlides);
	wb_box.restore_original_content.addEventListener(FlexEvent.BUTTON_DOWN, confirmRestoreOriginalContent);
	wb_box.restore_modified_content.addEventListener(FlexEvent.BUTTON_DOWN, confirmRestoreModifiedContent);
	wb_box.exit_full_screen.addEventListener(FlexEvent.BUTTON_DOWN, toggleFullScreen);	
	wb_box.addEventListener(KeyboardEvent.KEY_DOWN, KeyMove);
	wb_box.addEventListener(KeyboardEvent.KEY_UP, KeyZoom);
	wb_box.play.addEventListener(FlexEvent.BUTTON_DOWN, playVideo);
	wb_box.replay.addEventListener(FlexEvent.BUTTON_DOWN, replayVideo);
	wb_box.videoScrubber.addEventListener(FlexEvent.CHANGE_START, videoScrubPause);
	wb_box.videoScrubber.addEventListener(FlexEvent.CHANGE_END, videoScrubPlay);
	wb_box.editor.addEventListener("textFlowChanged", updateText);
	wb_box.wb_speaker.addEventListener(FlexEvent.BUTTON_DOWN, wbSpeakerStatus);
	wb_box.thumbnail_list.addEventListener(Event.CHANGE, goToPage);
	wb_box.slide_list.addEventListener(Event.CHANGE, goToPage);
	wb_box.contents_list_cmb.addEventListener(ListEvent.CHANGE, changeContentList, false, EventPriority.DEFAULT_HANDLER);
	wb_box.wb_viewport.viewport.addEventListener(PropertyChangeEvent.PROPERTY_CHANGE, syncScrollbar);
	
	
	if (!PRE_DOWNLOAD_SLIDE) {
		wb_box.slideimg.addEventListener(Event.COMPLETE, nextSlidePrediction);
		wb_box.svg.addEventListener(SVGEvent.PARSE_COMPLETE, nextSlidePrediction1);
	}
	wb_box.pen_size_cmb.dataProvider = penSizes;
	wb_box.pen_size_cmb.selectedIndex = 2; // set pen pixel size to 3
	wb_box.pen_color_pkr.selectedColor = 0xFF0000;  //set to color red
	wb_box.contents_list_cmb.dataProvider = contentsList;
	//	wb_box.pen_color_pkr.dataProvider = simpleDP;   // for few number of colors available on color picker
	
	//video timer
	video_timer = new Timer(PLAYHEAD_UPDATE_INTERVAL_MS);
	video_timer.addEventListener(TimerEvent.TIMER, videoTimerHandler);
}

private function resetWhiteboard(): void {
	myWbDebug("resetWhiteboard");
	
	wb_box.enabled = false;
	
	wb_box.chairman.selected = false;
	wb_box.presentor_action.selected = false;
	wb_box.presentor_action.enabled = false;
	wb_box.draw_mode.enabled = false;
	wb_box.draw_tool1.enabled = false;
	wb_box.draw_tool2.enabled = false;
	wb_box.page_tool.enabled = false;
	wb_box.page_tool2.enabled = false;
	wb_box.slide_list_box.enabled = false;
	wb_box.upload_tool.enabled = false;
	wb_box.content_tool.enabled = false;
	wb_box.function_mode_btn.enabled = false;
	wb_box.pen_btn.enabled = true;
	wb_box.cursor_btn.enabled = false;
	wb_box.eraser_btn.enabled = false;
	wb_box.cursorImg.visible = false;
	
	wb_box.present_page.text = "0";
	wb_box.last_page.text = "0";
	dragBoolean = false;
	penBoolean = false;
	textBoolean = false;
	cursorBoolean = true;
	eraserBoolean = false;
	is_presenter = false;
	is_chairman = false;
	is_offline_mode = false;
	isDrawStarted = false;
	
	wb_box.wb_container.scaleX = 1;
	wb_box.wb_container.scaleY = 1;
	
	// clear all layers
	wb_box.wb_area.removeAllElements();
	wb_box.slideimg.source = null;
	wb_box.video.removeChildren();
	
	// DrawingCanvas 
	drawing_layer = new Group();
	wb_box.wb_area.addElement(drawing_layer);
	// auto fit
	drawing_layer.setStyle("top", 0); 
	drawing_layer.setStyle("left", 0); 
	drawing_layer.setStyle("bottom", 0); 
	drawing_layer.setStyle("right", 0); 
	drawing_layer.addEventListener(MouseEvent.MOUSE_DOWN, startDrawing);
	drawing_layer.addEventListener(MouseEvent.MOUSE_OUT, stopDrawing); 
	drawing_layer.addEventListener(MouseEvent.MOUSE_UP, stopDrawing); 
	drawing_layer.addEventListener(MouseEvent.MOUSE_MOVE, doDrawing); 
	drawing_layer.addEventListener(MouseEvent.MOUSE_WHEEL, mouseWheel);
	
	image_files = null;
	wb_box.thumbnail_list.dataProvider = image_files;
	wb_box.thumbnail_list.validateNow();
	wb_box.slide_list.dataProvider = image_files;
	wb_box.slide_list.validateNow();
	
	updateWbButtons();
	
	// keep presenter role at autoreconnect
	if (is_auto_reconnection && is_presenter_reconnect) {
		wb_box.presentor_action.selected = true;
		wb_box.presentor_action.enabled = true;
		presenter_change(null);
	}
	
	// chairman function available only for member; disabled for guest
	if(userClass == "1") {
		wb_box.chairman.enabled = true;
		wb_box.chairman.label = resourceManager.getString('meeting_messages', 'label_chairman');
	} else {
		wb_box.chairman.enabled = false;
		wb_box.chairman.label = resourceManager.getString('meeting_messages', 'label_chairman_guest');
		wb_box.content_tool.includeInLayout = false;
	}
}

private function prepareWhiteboard(): void {
	// if not connectted (after logged-in)
	if (!is_wb_connected) {
		WBDEBUG = DEBUG;
		
		resetWhiteboard();
		
		myWbDebug("prepareWhiteboard : " + contentID);
		
		nc.call('init_params', null, contentID); // initial data on server 
		myWbDebug("NC.call : init_params");
		nc.call("getContentID", new Responder(loadContentData));
		myWbDebug("NC.call : getContentID");
		
		// enable drawing tools
		wb_box.tool_panel.enabled = true;
		wb_box.presentor_action.enabled = true;
		wb_box.offline_mode.enabled = true;
		
		// set connection status
		is_wb_connected = true;
	}
}	

/** 
 * Save data and no presenter status at the server prior to browser close
 **/
private function cleanWhiteboard(): void {
	myWbDebug("cleanWhiteboard");	
	if(is_presenter || is_chairman){
		if (is_chairman && (contentID != initContentID)) {
			changeContent(initContentID);
		}
		else if (is_presenter) {
			so_meeting.send("resetPage");
			myWbDebug("SO.send : resetPage");
			nc.call("keepData", null, 0, 0, 1.0, 0);
			myWbDebug("NC.call : keepData");
			nc.call("setLectureMode", null, MODE_CURSOR); // return to the cursor mode
			myWbDebug("NC.call : setLectureMode");
			// update status for lecture
			if (ENABLE_LECTURE_CLIENT) {
				nc.call("setPresenterID", null, clientID, false);
				myWbDebug("NC.call : setPresenterID");
			}
		}
	}
	
	//20140716
	if(is_chairman) {
		// remove chairman setting at server
		nc.call("setChairman", null, false);
		myDebug("NC.call : setChairman");
	}
	
	resetWhiteboard();
	
	// clear connection status
	is_wb_connected = false;
}


////////////////////Whiteboard Function////////////////////////////////////////

/** 
 * Add drawing canvass
 **/ 
public function syncAddLayer(userID:Number): void {
	myWbDebug("SO : syncAddLayer");
	if (userID != clientID) {
		this.addLayer();
	}
}

private function addLayer(): void {
	myWbDebug("addLayer : " + wb_box.wb_area.numElements);
	var layer:Group = new Group(); 
	layer.width = drawing_layer.width; 
	layer.height = drawing_layer.height;
	layer.x = 0;
	layer.y = 0; 
	wb_box.wb_area.addElementAt(layer, wb_box.wb_area.numElements - 1); 
	current_layer = layer;
}

/** 
 * Start Drawing / Cursor Mode
 **/
protected function startDrawing(evt:Event): void {
	if (isDrawStarted || (!is_presenter && !is_offline_mode)) { 
		return; 
	}
	
	//myWbDebug("startDrawing");
	if (penBoolean || eraserBoolean){
		myWbDebug("pen-based presentation tool");
		wb_box.cursorImg.visible = false;
		this.addLayer();
		
		// add new layer for listener
		if (!is_offline_mode) {
			so_meeting.send( "syncAddLayer", clientID );
			myWbDebug("SO.send : syncAddLayer");
		}
		
		var pen_color:uint = 0;
		if (penBoolean) {
			myWbDebug("drawing mode");
			pen_color = wb_box.pen_color_pkr.selectedColor;
		}
		else if (eraserBoolean) {
			myWbDebug("erasing mode");
			pen_color = 0xFFFFFF;
		}
		// for local
		// convert from actual position to percentage value
		draw_x = (drawing_layer.mouseX * 100) / drawing_layer.width;
		draw_y = (drawing_layer.mouseY * 100) / drawing_layer.height;
		current_layer.graphics.lineStyle(int(wb_box.pen_size_cmb.value), pen_color, 1);
		current_layer.graphics.moveTo(drawing_layer.mouseX, drawing_layer.mouseY);
		
		// for broadcasting
		if (!is_offline_mode) {
			so_meeting.send( "setDrawAttribs", int(wb_box.pen_size_cmb.value), pen_color, 1, clientID );
			myWbDebug("SO.send : setDrawAttribs");
			// save to memory
			nc.call("setDrawAttributes", null, int(wb_box.pen_size_cmb.value), pen_color);
			myWbDebug("NC.call : setDrawAttributes");
			nc.call("setDrawData", null, draw_x, draw_y);
			myWbDebug("NC.call : setDrawData");
		}
		
		isDrawStarted = true;
		
	} else if (cursorBoolean) {
		myWbDebug("cursor-based presentation tool");
		// convert from actual position to percentage value
		draw_x = (drawing_layer.mouseX * 100) / drawing_layer.width;
		draw_y = (drawing_layer.mouseY * 100) / drawing_layer.height;
		
		if (!is_offline_mode) {
			// directly display cursor for the presenter
			if (is_presenter) {
				showCursor(draw_x, draw_y, cursorBoolean);
			}
			so_meeting.send("syncCursor", draw_x, draw_y, cursorBoolean, clientID);
			myWbDebug("SO.send : syncCursor");
			nc.call("setCursorPosition", null, draw_x, draw_y);
			myWbDebug("NC.call : setCursorPosition");
			
			// for lecture client cursor synchronization
			if (ENABLE_LECTURE_CLIENT) {
				so_lecture.send("syncCursor",draw_x, draw_y);
				myDebug("SO_lecture.send : syncCursor");
			}
		}
		else {
			showCursor(draw_x, draw_y, cursorBoolean);
		}
	}
}

/** 
 * Start Drawing
 **/ 
protected function doDrawing(evt:MouseEvent): void {
	if (!isDrawStarted) {
		return;
	}
	
	if (penBoolean || eraserBoolean){
		//myWbDebug("doDrawing");
		var pen_color:uint = 0;
		if (penBoolean) {
			pen_color = wb_box.pen_color_pkr.selectedColor;
		}
		else if (eraserBoolean) {
			pen_color = 0xFFFFFF;
		}
		
		// draw on local
		// convert from actual position to percentage value
		var new_draw_x:Number = (drawing_layer.mouseX * 100) / drawing_layer.width;
		var new_draw_y:Number = (drawing_layer.mouseY * 100) / drawing_layer.height;
		current_layer.graphics.lineTo(drawing_layer.mouseX, drawing_layer.mouseY);
		// share to other if does not use offline mode
		if (!is_offline_mode) {
			so_meeting.send( "drawLine", draw_x, draw_y, new_draw_x, new_draw_y, clientID);
			myWbDebug("SO.send : drawLine");
			// save to memory
			nc.call("setDrawData", null, new_draw_x, new_draw_y);
			myWbDebug("NC.call : setDrawData");
		}
		// change to current position
		draw_x = new_draw_x;
		draw_y = new_draw_y;
	}
}

/** 
 * Synchronize Cursor
 **/ 
public function syncCursor(cursor_x:Number, cursor_y:Number, display:Boolean = false, userID:Number = 0): void {
	if (clientID != userID && !is_offline_mode) {
		myWbDebug("SO.recv : syncCursor");
		showCursor(cursor_x, cursor_y, display);
	}
}

/** 
 * Show Cursor
 **/ 
private function showCursor(cursor_x:Number, cursor_y:Number, display:Boolean = false): void {
	myWbDebug("showCursor");
	if (cursorBoolean || display) {
		// convert from percentage value to actual position
		var new_cursor_x:Number = (cursor_x * drawing_layer.width) / 100;
		var new_cursor_y:Number = (cursor_y * drawing_layer.height) / 100;
		wb_box.cursorImg.visible = true;
		wb_box.cursorImg.x = new_cursor_x - 8;
		wb_box.cursorImg.y = new_cursor_y - 8;
	}
}

/** 
 * Stop Drawing
 **/ 
protected function stopDrawing(evt:MouseEvent): void {
	if (!isDrawStarted || !is_logging_in) {
		return;
	}
	
	myWbDebug("stopDrawing");
	if (penBoolean || eraserBoolean){
		if (!is_offline_mode) {
			// save to memory (add end point of line)
			nc.call("setDrawData", null, -1, -1);
			myWbDebug("NC.call : setDrawData");
		}
	}
	
	isDrawStarted = false;
}

/** 
 * Set Drawing Attributes
 **/ 
public function setDrawAttribs(thickness:int, color:uint, def:int, userID:Number): void {
	myWbDebug("SO.recv : syncAddLayer");
	if (userID != clientID) {
		// do not draw from the presenter while using offline mode
		if (!is_offline_mode) {
			current_layer.graphics.lineStyle(thickness, color, def); 
		}
	}
}

/** 
 * Start Drawing
 **/ 
public function drawLine(startX:Number, startY:Number, endX:Number, endY:Number, userID:Number): void {
	myWbDebug("SO.recv : syncAddLayer");
	if (userID != clientID) {
		// do not draw from the presenter while using offline mode
		if (!is_offline_mode) {
			var new_start_x:Number = (startX * current_layer.width) / 100;
			var new_start_y:Number = (startY * current_layer.height) / 100;
			var new_end_x:Number = (endX * current_layer.width) / 100;
			var new_end_y:Number = (endY * current_layer.height) / 100;
			current_layer.graphics.moveTo(new_start_x, new_start_y); 
			current_layer.graphics.lineTo(new_end_x, new_end_y); 
		}
	}
}

/** 
 * Draw Existing Annotation Data 
 **/
private function drawExistingData(result:Array): void {
	myWbDebug("drawExistingData");
	
	// show busy cursor
	if (CursorManager.currentCursorID == 0) { 
		CursorManager.setBusyCursor();
	}
	so_meeting.send("doExistingData", result, clientID);
	myWbDebug("SO.send : doExistingData");
}

public function doExistingData(result:Array, userID:Number): void {
	if (clientID == userID) {
		myWbDebug("SO.recv : doExistingData");
		this.resetLayer();
		if (result.length > 0) {
			this.addLayer();
			var i:int = 0;
			var dataPackLen:int = 2;
			var is_set_attrib:Boolean = true;
			while (i < result.length) {
				// if found new line, add new layer
				if ((result[i] == -1) && (result[i+1] == -1)) {
					// ignore the last end point of line
					if (i < (result.length - dataPackLen - 1)) {
						//myWbDebug("found new draw section");
						this.addLayer();
						is_set_attrib = true;
					}
				}
				// draw data
				else {
					if (is_set_attrib) {
						//myWbDebug("set draw attributes");
						current_layer.graphics.lineStyle(result[i], result[i+1], 1);
						
						// move to next data set
						i += dataPackLen;
						// set the first point
						var point_x:Number = (result[i] * drawing_layer.width) / 100;
						var point_y:Number = (result[i+1] * drawing_layer.height) / 100;
						current_layer.graphics.moveTo(point_x, point_y); 
					}
					else {
						var point_x:Number = (result[i] * drawing_layer.width) / 100;
						var point_y:Number = (result[i+1] * drawing_layer.height) / 100;
						current_layer.graphics.lineTo(point_x, point_y);
					}
					is_set_attrib = false;
				}
				i += dataPackLen;
			}
		}
		
		// for prediction downloading (only for annotation mode)
		if (!PRE_DOWNLOAD_SLIDE) {
			nextSlidePrediction(null);
		}
		
		// clear cursor
		CursorManager.removeBusyCursor();
	}
}

private function showOfflinePage(): void {  
	myWbDebug("showOfflinePage");
	/*
	wb_box.wb_viewport.viewport.x = 0;
	wb_box.wb_viewport.viewport.y = 0;
	wb_box.wb_viewport.viewport.horizontalScrollPosition = 0;
	wb_box.wb_viewport.viewport.verticalScrollPosition = 0;	
	wb_box.wb_container.scaleX = 1;
	wb_box.wb_container.scaleY = 1;
	//zoom_value = 0;
	*/
	
	syncSlideImage();
}

/** 
 * Synchronize Vertical and Horizontal Scrollbars   
 **/
private function syncScrollbar(event:PropertyChangeEvent):void {
	if (is_presenter && !is_offline_mode) {
		//myWbDebug("syncScrollbar");
		if (syncScrollInterval == 0) {
			syncScrollInterval = setInterval(syncScrollbarEvent, 500); // update scroll position
		}
	}
}

private function syncScrollbarEvent():void {
	myWbDebug("syncScrollbarEvent");
	
	scrollbar_x = (wb_box.wb_viewport.viewport.horizontalScrollPosition * 100) / wb_box.wb_viewport.viewport.width;
	scrollbar_y = (wb_box.wb_viewport.viewport.verticalScrollPosition * 100) / wb_box.wb_viewport.viewport.height;
	so_meeting.send("doSyncScrollbar", scrollbar_x, scrollbar_y, clientID);
	myWbDebug("SO.send : doSyncScrollbar : " + scrollbar_x + ", " + scrollbar_y);
	setPageState();
		
	// clear timer
	clearInterval(syncScrollInterval);
	syncScrollInterval = 0;
}

public function doSyncScrollbar(pos_x:Number, pos_y:Number, userID:Number): void {
	if (userID != clientID) {
		myWbDebug("SO.recv : doSyncScrollbar");
		
		var new_pos_x:Number = (pos_x * wb_box.wb_viewport.viewport.width) / 100;
		var new_pos_y:Number = (pos_y * wb_box.wb_viewport.viewport.height) / 100;
		
		wb_box.wb_viewport.viewport.horizontalScrollPosition = new_pos_x;
		wb_box.wb_viewport.viewport.verticalScrollPosition = new_pos_y;	
	}
}

private function updateWbButtons(): void {
	myWbDebug("updateWbButtons");
	
	if (is_presenter) {
		wb_box.draw_mode.enabled = true;
		wb_box.draw_tool1.enabled = true;
		wb_box.draw_tool2.enabled = true;
		wb_box.page_tool.enabled = true;
		wb_box.page_tool2.enabled = true;
		wb_box.slide_list_box.enabled = true;
		wb_box.upload_tool.enabled = true;
		wb_box.video_control.visible = true;
	}
	else if (is_offline_mode) {
		wb_box.draw_mode.enabled = true;
		wb_box.draw_tool1.enabled = true;
		wb_box.draw_tool2.enabled = true;
		wb_box.page_tool.enabled = true;
		wb_box.page_tool2.enabled = true;
		wb_box.slide_list_box.enabled = true;
		wb_box.upload_tool.enabled = false;
		wb_box.video_control.visible = true;
		//wb_box.content_tool.enabled = false;
	}
	else {
		wb_box.draw_mode.enabled = false;
		wb_box.draw_tool1.enabled = false;
		wb_box.draw_tool2.enabled = false;
		wb_box.page_tool.enabled = false;
		wb_box.page_tool2.enabled = false;
		wb_box.slide_list_box.enabled = false;
		wb_box.upload_tool.enabled = false;
		wb_box.video_control.visible = false;
		//wb_box.content_tool.enabled = false;
	}
	
	if (is_chairman) {
		wb_box.content_tool.visible = true;
		wb_box.content_tool.enabled = true;
	}
	else {
		wb_box.content_tool.visible = false;
		wb_box.content_tool.enabled = false;
	}
	
	// disable draw tools when using cursor mode
	if (cursorBoolean) {
		wb_box.draw_tool1.enabled = false;
	}
	else if (penBoolean) {
		wb_box.draw_tool1.enabled = true;
	}
}

// function for defining status of navigation buttons
private function updateNaviButtons(): void {
	myWbDebug("updateNaviButtons");
	
	// move first and previous buttons
	if (present_page_num <= 1) {
		wb_box.first_page.enabled = false;
		wb_box.previous_page.enabled = false;
		
		// focus the whitebaord area to activate the key event
		meetingPanel.focusManager.setFocus(whiteboardArea.wb_viewport);
	}
	else {
		wb_box.first_page.enabled = true;
		wb_box.previous_page.enabled = true;
	}
	
	// move last and next buttons
	if (present_page_num >= last_page_num) {
		wb_box.next_page.enabled = false;
		wb_box.end_page.enabled = false;
		
		// focus the whitebaord area to activate the key event
		meetingPanel.focusManager.setFocus(whiteboardArea.wb_viewport);
	}
	else {
		wb_box.next_page.enabled = true;
		wb_box.end_page.enabled = true;
	}
}

private function setPageState(): void {
	if (is_presenter && !is_offline_mode) {
		//myWbDebug("setPageState");
		nc.call("setPageState", null, scrollbar_x, scrollbar_y, wb_box.wb_container.scaleX, zoom_value);
		myWbDebug("NC.call : setPageState");
	}
}

/** 
 * Remove last drawing canvass
 **/ 
private function undo(evt:Event): void { 
	so_meeting.send("syncUndo",clientID); 
	myWbDebug("SO.send : syncUndo");
}

//Extend Canvas
private function expand(evt:Event): void {
	so_meeting.send("syncExpand");
	myWbDebug("SO.send : syncExpand");
}

//Extend Width Canvas
private function expandw(evt:Event): void {
	so_meeting.send("syncExpandw"); 
	myWbDebug("SO.send : syncExpandw");
}

//dxtend Canvas
private function depand(evt:Event): void {
	if (wb_box.wb_area.height > 575) {
		so_meeting.send("syncDepand", false); 
		myWbDebug("SO.send : syncDepand");
	} else {
		Alert.show("More than the Limit！");
	}
}

//dxtend Canvas
private function depandw(evt:Event): void {
	myWbDebug("depandw");
	if (wb_box.wb_area.width > 990) {
		so_meeting.send("syncDepandw", true); 
		myWbDebug("SO.send : syncDepandw");		
	} else {
		Alert.show("More than the Limit！");
	}
}

//Clear Canvas
private function clearDrawing(evt:Event): void {
	if (!is_offline_mode) {
		// clear on all clientss
		so_meeting.send("resetLayerFromCenter");
		myWbDebug("SO.send : resetLayerFromCenter");
		// clear data on server
		nc.call('clearDrawData', null);
		myWbDebug("NC.call : clearDrawData");
	}
	else {
		// only clear on local
		this.resetLayer();
	}
}

// clear and reset page environment
public function resetPage(): void {
	myWbDebug("SO : resetPage");
	
	zoomFit();
	this.resetLayer();
}

//Zoom Out Canvas
private function zoomOut(evt:Event = null): void {
	if (wb_box.wb_container.scaleX > 1) {
		//myWbDebug("zoomOut");
		// process on local
		processZoomOut();
		setPageState();
		
		// process for others
		if (is_presenter && !is_offline_mode){
			so_meeting.send("doZoomOut", clientID);
			myWbDebug("SO.send : doZoomOut");
		}
	}
	else {
		wb_box.dragging.enabled = false;
	}
	
}

public function doZoomOut(senderID:Number): void {
	if (senderID != clientID) {
		myWbDebug("SO.recv : doZoomOut");
		processZoomOut();
	}
}

private function processZoomOut(): void {
	myWbDebug("processZoomOut");
	wb_box.wb_container.scaleX = (wb_box.wb_container.scaleX > 1) ? wb_box.wb_container.scaleX - 0.2 : 1;
	wb_box.wb_container.scaleY = (wb_box.wb_container.scaleY > 1) ? wb_box.wb_container.scaleY - 0.2 : 1;
}

//Zoom In Canvas
private function zoomIn(evt:Event = null): void {
	if (wb_box.wb_container.scaleX < zoom_value_max) {
		//myWbDebug("zoomIn");
		// process on local
		processZoomIn();
		setPageState();
		
		// process for others
		if (is_presenter && !is_offline_mode) {
			wb_box.dragging.enabled = true;
			so_meeting.send("doZoomIn", clientID);
			myWbDebug("SO.send : doZoomIn");
		}
	}
}

public function doZoomIn(senderID:Number): void {
	if (senderID != clientID) {
		myWbDebug("SO.recv : doZoomIn");
		processZoomIn();
	}
}

private function processZoomIn(): void {
	myWbDebug("processZoomIn");
	wb_box.wb_container.scaleX = (wb_box.wb_container.scaleX < zoom_value_max) ? wb_box.wb_container.scaleX + 0.2 : zoom_value_max;
	wb_box.wb_container.scaleY = (wb_box.wb_container.scaleY < zoom_value_max) ? wb_box.wb_container.scaleY + 0.2 : zoom_value_max;
}

//Return from zoom
private function zoomFit(evt:Event = null): void {
	isA4Zoom = false;
	if (wb_box.wb_container.scaleX != 1) {
		//myWbDebug("zoomFit");
		// process on local
		processZoomFit();
		setPageState();
		
		// process for others
		if (is_presenter && !is_offline_mode) {
			wb_box.dragging.enabled = false;
			so_meeting.send("doZoomFit", clientID);
			myWbDebug("SO.send : doZoomFit");
		}
	}
}

public function doZoomFit(senderID:Number): void {
	if (senderID != clientID) {
		myWbDebug("SO.recv : doZoomFit");
		processZoomFit();
	}
}

private function processZoomFit(): void {
	myWbDebug("processZoomFit");
	wb_box.wb_container.scaleX = 1;
	wb_box.wb_container.scaleY = 1;
	wbArea.validateNow();
	
	//zoom_value = 0;
	scrollbar_x = 0;
	scrollbar_y = 0;
	wb_box.wb_viewport.viewport.horizontalScrollPosition = scrollbar_x;
	wb_box.wb_viewport.viewport.verticalScrollPosition = scrollbar_y;
}

// zoom A4 or fit width 
private function zoomA4(evt:Event = null): void {
	if (wb_box.wb_container.scaleX >= 1) {
		//myWbDebug("zoomA4");
		// process on local
		isA4Zoom = true;
		processZoomA4();
		setPageState();
		
		// process for others
		if (is_presenter && !is_offline_mode) {
			wb_box.dragging.enabled = false;
			so_meeting.send("doZoomA4", clientID);
			myWbDebug("SO.send : doZoomA4");
		}
	}
}

public function doZoomA4(senderID:Number): void {
	if (senderID != clientID) {
		myWbDebug("SO.recv : doZoomA4");
		processZoomA4();
	}
}

private function processZoomA4(): void {
	myWbDebug("processZoomA4");

	if (wb_box.slideimg.visible) {
		if ( wb_box.slideimg.sourceHeight > wb_box.slideimg.sourceWidth ) {
			wb_box.wb_container.scaleX = 2.2;
			wb_box.wb_container.scaleY = 2.2;
			wbArea.validateNow();
			//	scrollbar_x = (wb_box.wb_viewport.viewport.contentWidth - wb_box.slideimg.sourceWidth)　/　8;
			scrollbar_x = 60;
			scrollbar_y = 0;
			setScrollbar(scrollbar_x, scrollbar_y);
		} 
	} else if (wb_box.svg.visible) {
		var svgDoc:SVGDocument = wb_box.svg.svgDocument;
		var scaleX:Number = (wb_box.svg.width - 10) / svgDoc.width;  // 10 = gap
		var scaleY:Number = (wb_box.svg.height - 10) / svgDoc.height;
		
		if ( svgDoc.height > svgDoc.width ) {
			myWbDebug("svgDoc.width - " + svgDoc.width);
			myWbDebug("svgDoc.height - " + svgDoc.height);
			wb_box.svg.scaleX = (scaleX < scaleY) ? scaleX : scaleY;
			wb_box.svg.scaleY = wb_box.svg.scaleX;
			wb_box.wb_container.scaleX = 2.2;
			wb_box.wb_container.scaleY = 2.2;
			wbArea.validateNow();
			scrollbar_x = 60;
			scrollbar_y = 0;
			setScrollbar(scrollbar_x, scrollbar_y);
		}
	}
}

private function setScrollbar(pos_x:Number, pos_y:Number): void {
	myWbDebug("setScrollbar");
		
	var new_pos_x:Number = (pos_x * wb_box.wb_viewport.viewport.width) / 100;
	var new_pos_y:Number = (pos_y * wb_box.wb_viewport.viewport.height) / 100;
	
	wb_box.wb_viewport.viewport.horizontalScrollPosition = new_pos_x;
	wb_box.wb_viewport.viewport.verticalScrollPosition = new_pos_y;	
}

public function syncUndo(userID:Number): void { 
	//if (userID!=clientID) {
	var v:int = wb_box.wb_area.numElements; 
	trace(v); 
	if (v > 1) { 
		wb_box.wb_area.removeElementAt( v - 2 ); 
	}
}

private function onChangeBGAlpha(e:SliderEvent): void { 
	myWbDebug("onChangeBGAlpha");
	drawing_layer.setStyle("backgroundAlpha",bg_alpha_slider.value/100); 1
}

private function onChangeBGColor(evt:Event): void { 
	myWbDebug("onChangeBGColor");
	drawing_layer.setStyle("backgroundColor", bg_color_picker.value); 
}
// Enable the draggin button to move the slide after zoomIn
private function dragMode(evt:Event):void {
	myWbDebug("Dragging Function");
	dragBoolean = true;
	cursorBoolean = !dragBoolean;
	penBoolean = !dragBoolean;
	eraserBoolean = !dragBoolean;
	wb_box.cursor_btn.enabled = true;
	wb_box.eraser_btn.enabled = false;
	wb_box.pen_btn.enabled = true;
}

public function startScrollingImg(event:MouseEvent):void {
	if (dragBoolean){
		myWbDebug("Start dragging");
		is_scrolling_viewport = true;
		mouseMoveX = event.stageX;
		mouseMoveY = event.stageY;
	}
}

public function scrollingImg(event:MouseEvent):void {
	if (dragBoolean && is_scrolling_viewport && wb_box.wb_container.scaleX > 1) {
		myWbDebug("Drag Image");
		newScrollPosX = mouseMoveX - event.stageX;
		newScrollPosY = mouseMoveY - event.stageY;
		wb_box.wb_viewport.viewport.horizontalScrollPosition = wb_box.wb_viewport.viewport.horizontalScrollPosition + newScrollPosX;	
		wb_box.wb_viewport.viewport.verticalScrollPosition = wb_box.wb_viewport.viewport.verticalScrollPosition + newScrollPosY;					
		mouseMoveX = event.stageX;
		mouseMoveY = event.stageY;
	}
}

public function stopScrollingImg(event:MouseEvent):void {
	if (dragBoolean){
		myWbDebug("Stop dragging");
		is_scrolling_viewport = false;
	}
}


private function drawMode(evt:Event): void {
	myWbDebug("Start Drawing");
	wb_box.cursor_btn.enabled = true;
	wb_box.eraser_btn.enabled = true;
	wb_box.pen_btn.enabled = false;
	wb_box.cursorImg.visible = false;
	penBoolean = true;
	cursorBoolean = !penBoolean;
	eraserBoolean = !penBoolean;
	dragBoolean = !penBoolean;
	wb_box.pen_size_cmb.selectedIndex = 2; // set pen pixel size to 3
	wb_box.pen_color_pkr.selectedColor = 0xFF0000;  //set to color red
	
	// retrieve existing draw data after swithed from cursor mode
	if (!is_offline_mode) {
		so_meeting.send("updateData", cursorBoolean);
		myWbDebug("SO.send : updateData");
		// save a lecture mode at the server
		nc.call("setLectureMode", null, (cursorBoolean ? MODE_CURSOR : MODE_ANNOTATION));
		myWbDebug("NC.call : setLectureMode");
	}

	
	updateWbButtons();
}

private function cursorMode(evt:Event): void {
	wb_box.cursor_btn.enabled = false;
	wb_box.eraser_btn.enabled = false;
	wb_box.pen_btn.enabled = true;
	cursorBoolean = true;
	penBoolean = !cursorBoolean;
	eraserBoolean = !cursorBoolean;
	dragBoolean = !cursorBoolean;
	if (!is_offline_mode) {
		so_meeting.send("updateData", cursorBoolean);
		// clear on all clients
		so_meeting.send("resetLayerFromCenter");
		myWbDebug("SO.send : resetLayerFromCenter");
		// save a lecture mode at the server
		nc.call("setLectureMode", null, (cursorBoolean ? MODE_CURSOR : MODE_ANNOTATION));
		myWbDebug("NC.call : setLectureMode");
	}
	else {
		// only clear on local
		this.resetLayer();
	}
	
	updateWbButtons();
}

private function eraseMode(evt:Event): void {
	wb_box.cursor_btn.enabled = true;
	wb_box.eraser_btn.enabled = false;
	wb_box.pen_btn.enabled = true;
	eraserBoolean = true;
	cursorBoolean = !eraserBoolean;
	penBoolean = !eraserBoolean;
	dragBoolean = !eraserBoolean;
	wb_box.pen_size_cmb.selectedIndex = 5;
	
	updateWbButtons();
} 

private function textAnnotationFunc(evt:Event): void {
	myWbDebug("textAnnotation");
	// Create the TitleWindow container.
	var textAnnotationWindow:TitleWindow = PopUpManager.createPopUp(this, textAnnotation, false) as TitleWindow;
	// Center the pop-up window
	PopUpManager.centerPopUp(textAnnotationWindow);
	// Add title to the title bar.
	textAnnotationWindow.title="Text Annotation";
	// Make title bar slightly transparent.
	textAnnotationWindow.setStyle("borderAlpha", 0.9);
	// Hide the close button.
	//textAnnotationWindow.closeButton.visible = true;
} 

public function syncExpand(is_w_expand:Boolean): void {
	myWbDebug("syncExpand");
	if (is_w_expand) {
		wb_box.wb_area.width = wb_box.wb_area.width+1000;
		drawing_layer.width = wb_box.wb_area.width;
		width_value = width_value+1;
		
	} else {
		wb_box.wb_area.height = wb_box.wb_area.height+1000;
		drawing_layer.height = wb_box.wb_area.height;
		height_value = height_value+1;
	}
	setPageState();
}

public function syncDepand(is_w_depand:Boolean): void {
	myWbDebug("syncDepand");
	if (is_w_depand) {
		wb_box.wb_area.width = wb_box.wb_area.width-1000;
		drawing_layer.width = wb_box.wb_area.width;
		width_value = width_value-1;
	} else {
		wb_box.wb_area.height = wb_box.wb_area.height-1000;
		drawing_layer.height = wb_box.wb_area.height;
		height_value = height_value-1;
	}
	setPageState();
}

// this function for checking reset command from a presenter
// if it is not offline mode, clear all layers
public function resetLayerFromCenter(): void {
	myWbDebug("SO.recv : resetLayerFromCenter");
	if (!is_offline_mode) {
		wb_box.cursorImg.visible = false;
		this.resetLayer();
	}
}

// cleare all layers
private function resetLayer(): void {
	myWbDebug("resetLayer");
	// remove all, except a drawing_layer 
	while (wb_box.wb_area.numElements > 1) {
		wb_box.wb_area.removeElementAt(0);
	}
	
	// remove "BUSY" mouse pointer 
	CursorManager.removeBusyCursor();
}

//Mouse Wheel
private function mouseWheel(e:MouseEvent): void {
	//Alert.show(e.stageY.toString());
	so_meeting.send("syncMouseWheel",e.delta,clientID);
	myWbDebug("SO.send : syncMouseWheel");
}

public function syncMouseWheel(delta:Number,userID:Number): void {
	if (userID != clientID) {
		
	}
}

//---Save Image----------//
private function snapshotHandler(): void {
	var snapshot:ImageSnapshot=ImageSnapshot.captureImage(drawing_layer);
	//file.save()snapshot.data,"canvas.png";
}

//---Upload File--------//
private function selectFileStart(evt:Event): void {
	myWbDebug("selectFileStart");
	file = new FileReference;
	file.addEventListener(Event.SELECT, selectFileEnd);
	file.addEventListener(Event.COMPLETE, uploadEnd);
	file.addEventListener(flash.events.IOErrorEvent.IO_ERROR, uploadError);
	
	var filter:Array = new Array();
	filter.push(new FileFilter(resourceManager.getString('meeting_messages', 'pdf_filter_text'), "*.pdf"));
	filter.push(new FileFilter(resourceManager.getString('meeting_messages', 'presentation_filter_text'), "*.odp;*.sxi;*.ppt;*.pptx"));
	filter.push(new FileFilter(resourceManager.getString('meeting_messages', 'document_filter_text'), "*.odt;*.sxw;*.doc;*.docx"));
	filter.push(new FileFilter(resourceManager.getString('meeting_messages', 'image_filter_text'), "*.png;*.jpg;*.jpeg,*.tif,*.tiff;*.bmp"));
	filter.push(new FileFilter(resourceManager.getString('meeting_messages', 'video_filter_text'), "*.mov;*.avi;*.wmv;*.mpg;*.ogg;*.mp4;*.flv"));
	file.browse(filter);
}

private function selectFileEnd(evt:Event): void {
	myWbDebug("selectFileEnd");
	request = new URLRequest;
	request.url = "http://" + meetingServer + "/" + meeting_home + "/servlet/wbUploadFile?room=" + contentID + "&convOutput=" + file_conversion_output  + "&orig=0";;
	file.upload(request, "filedata", false);
	CursorManager.setBusyCursor();
}

private function uploadEnd(evt:Event): void {
	myWbDebug("uploadEnd");
	
	pgTimer = new Timer(500);
	pgTimer.addEventListener(TimerEvent.TIMER, progressHandler);
	pgTimer.start();	
}

private function uploadError(evt:Event): void {
	myWbDebug("uploadError");
	Alert.show(resourceManager.getString('meeting_messages', 'alert_error'));
	CursorManager.removeBusyCursor();
}

private function progressHandler(event:TimerEvent) : void {
	myWbDebug("progressHandler");
	nc.call("isConvertComplete", new Responder(executeResult), contentID);
	myWbDebug("NC.call : isConvertComplete");
}

private function executeResult(status:Boolean):void {
	myWbDebug("isConvertComplete : " + status );
	if (status) {
		CursorManager.removeBusyCursor();
		Alert.show(resourceManager.getString('meeting_messages', 'alert_upload_complete')); 
		
		myWbDebug("keep existing edited data");
		for (var i:int = 0; i < image_files.length; i++) {
			var page:int = image_files.getItemAt(i).page;
			var title:String = image_files.getItemAt(i).title;
			var image:String = image_files.getItemAt(i).image_src;
			var description:String = image_files.getItemAt(i).description;
			
			nc.call("setEditorData", null, ((i == 0) ? true : false), page, title, image, description);
			myWbDebug("NC.call : setEditorData");
			
			//insert new file after the selected slide position
			if(i == wb_box.thumbnail_list.selectedIndex) {  
				nc.call("insertEditorData", null, contentID, true, false);
				myDebug("NC.call : insertEditorData");
				myDebug("insert_slide_position : " + present_page_num);
			} 
		}
		
		// generate the content template
		nc.call("genEditorTemplate", null, contentID, true, false, false);
		myWbDebug("NC.call : genEditorTemplate");
		wait(300);
		so_meeting.send("loadContentData", contentID);
		myWbDebug("SO.send : loadContentData");
		pgTimer.stop();
	}
}

public function loadContentData(cid:String):void {
	if (is_logging_in){  // protect for logout step
		myWbDebug("SO.recv/NC.responder : loadContentData");
		if (cid != contentID && cid != null) {
			contentID = cid;
		}
		if (CursorManager.currentCursorID == 0) { 
			CursorManager.setBusyCursor();
		}
		// fixed always read data from cache
		var loader:URLLoader = new URLLoader();
		var header:URLRequestHeader = new URLRequestHeader("pragma", "no-cache");
		
		if(is_chairman_exist) {
			var url:URLRequest = new URLRequest(contentID + "/external/content_description.xml");
			myWbDebug("content file = " + contentID + "/external/content_description.xml");
		} else {
			var url:URLRequest = new URLRequest(contentID + "/working/content_description.xml");
			myWbDebug("content file = " + contentID + "/working/content_description.xml");
		}
		url.requestHeaders.push(header);
		url.method = URLRequestMethod.GET;
		url.data = new URLVariables("time="+Number(new Date().getTime()));
		loader.addEventListener(Event.COMPLETE, retrieveContentData);
		loader.load(url);
		
		resetLayerFromCenter();
	}
}

// get data from the metadata
private function retrieveContentData(event:Event): void {
	myWbDebug("retrieveContentData");
	
	var xml:XML = new XML(event.target.data);
	
	var i:int;
	var slide_title :String; // Title of slide
	var img_src:String; // Link of slide image
	var image:String; // Link of slide image
	var thumb:String; // Link of thumb image
	var slide_info :String; // Description of slide
	var slide_type:String; //Type of media (image, vector, video)
	
	// get slides data
	image_files = new ArrayCollection();
	for(i = 0; i < xml.slides.slide.length();i++ ) {
		slide_type = ((xml.slides.slide[i].attribute("type") == null) || (xml.slides.slide[i].attribute("type").length() == 0)) ? "image" : xml.slides.slide[i].attribute("type");
		img_src = xml.slides.slide[i];
		if (slide_type.toLowerCase() == "video") {
			image = contentID + "/working/" + img_src;
			thumb = contentID + "/working/flv/thumb/" + img_src;
		}
		else {
			image = contentID + "/working/files/" + img_src;
			thumb = contentID + "/working/files/thumb/" + img_src;
		}
		slide_title = xml.slides.slide[i].attribute("title");
		slide_info = xml.slides.slide[i].attribute("info");
		image_files.addItem({page:(i+1), title:slide_title, image:image, thumb:thumb, image_src:img_src, description:slide_info, type:slide_type});		
	}
	
	// set the maximum page
	myWbDebug("total slides = " + image_files.length);
	last_page_num = image_files.length;	// total number of slides
	wb_box.last_page.text = last_page_num.toString();
	
	// apply pre-download slides
	if (PRE_DOWNLOAD_SLIDE) {
		preDownloadSlide();
	}
	// slide by slide loading
	else {
		getCurrentSlide();
	}
	CursorManager.removeBusyCursor();
}

// pre-download all slides after logged-in
private function preDownloadSlide():void {
	myWbDebug("preDownloadSlide : contentID = " + contentID);
	
	if (image_files != null) {
		if (CursorManager.currentCursorID == 0) { 
			CursorManager.setBusyCursor();
		}
		
		pgAlert = Alert.show("Downloading content... \nPlease wait.","Content download", Alert.OK, this);
		pgAlert.mx_internal::alertForm.removeChild(pgAlert.mx_internal::alertForm.mx_internal::buttons[0]); // hidden / remove button
		
		preDownloadSlideCount = 0;
		preDownloadThumbCount = 0;
		
		for (var i:int = 0; i < image_files.length; i++) {
			// load slide image (to browser's cache)
			var preSlideLoader:URLLoader = new URLLoader();
			var preSlideRequest:URLRequest = new URLRequest(image_files.getItemAt(i).image);
			preSlideLoader.addEventListener(Event.COMPLETE, onPredownloadSlideComplete);
			preSlideLoader.load(preSlideRequest);
			
			// thumb image
			var preThumbLoader:URLLoader = new URLLoader();
			var preThumbRequest:URLRequest = new URLRequest(image_files.getItemAt(i).thumb);
			preThumbLoader.addEventListener(Event.COMPLETE, onPredownloadThumbComplete);
			preThumbLoader.load(preThumbRequest);
		}
		
		pgTimer = new Timer(500);
		pgTimer.addEventListener(TimerEvent.TIMER, checkPredownloadComplete);
		pgTimer.start();
	}
}

private function onPredownloadSlideComplete(event:Event):void {
	//myWbDebug("image download has been completed");
	preDownloadSlideCount++;
}

private function onPredownloadThumbComplete(event:Event):void {
	//myWbDebug("image download has been completed");
	preDownloadThumbCount++;
}

private function checkPredownloadComplete(event:TimerEvent):void {
	if((preDownloadSlideCount >= last_page_num) && (preDownloadThumbCount >= last_page_num)) {
		myWbDebug("images download has been completed");
		
		pgTimer.stop();
		CursorManager.removeBusyCursor();
		PopUpManager.removePopUp(pgAlert);
		
		if (is_first_connect) {
			so_meeting.send("getLoginName"); // Get user names of all connections
			myWbDebug("SO.send : getLoginName");
		}
		
		getCurrentSlide();
	}
}

private function getCurrentSlide():void {
	myWbDebug("getCurrentSlide");
	
	nc.call("getRoomState", new Responder(setRoomState));
	myWbDebug("NC.call : getRoomState");
	
	// show images in the slide list
	wb_box.thumbnail_list.dataProvider = image_files;
	wb_box.thumbnail_list.validateNow();
	wb_box.thumbnail_list.selectedIndex = present_page_num - 1; // set to the first slide
	wb_box.thumbnail_list.scrollToIndex(wb_box.thumbnail_list.selectedIndex);
	
	wb_box.slide_list.dataProvider = image_files;
	wb_box.slide_list.validateNow();
	wb_box.slide_list.selectedIndex = present_page_num - 1; // set to the first slide
	wb_box.slide_list.scrollToIndex(wb_box.slide_list.selectedIndex);
	
	// enable whiteboard
	wb_box.enabled = true;
}

// set the current room state from server
private function setRoomState(result:Array): void {
	myWbDebug("setRoomState");
	
	setSlideNumber(result[0]);
	checkLectureMode(result[4]);
	updateNaviButtons();
}

// set current slide number
public function setSlideNumber(new_page:int, old_page:int = 1, skip_sync_slide:Boolean = false):void {
	if (is_logging_in && !is_offline_mode) { // protect for logout step
		myWbDebug("SO.recv : setSlideNumber : new_page = " + new_page);
		present_page_num = new_page;
		old_page_num = old_page;
		
		if (!skip_sync_slide) {
			syncSlideImage();
		}
		// clear annotation data
		this.resetLayer();
	}
}

// set current room title
public function setContentTitle(title:String):void {
		myWbDebug("SO.recv : setContentTitle - " + title);
		wb_box.contentTitle.text = title;
}


// update the latest data from server
public function updateData(is_cursor_mode:Boolean = false): void {
	myWbDebug("SO.recv : updateData : page = " + present_page_num);
	if (!is_offline_mode) {
		wb_box.cursorImg.visible = false; // always hide the cursor
		// update current mode
		cursorBoolean = is_cursor_mode;
		penBoolean = !cursorBoolean;
		eraserBoolean = !cursorBoolean;
		
		if (!is_cursor_mode) {
			if (CursorManager.currentCursorID == 0) { 
				CursorManager.setBusyCursor();
			}
			// retrieve existing draw data
			nc.call('getDrawData', new Responder(drawExistingData));
			myWbDebug("NC.call : getDrawData");
		}
	}
}

// display the current slide
private function syncSlideImage(): void {
	myWbDebug("syncSlideImage");
	// set background image
	if (image_files != null) {
		if (CursorManager.currentCursorID == 0) { 
			CursorManager.setBusyCursor();
		}
		
		wb_box.present_page.text = present_page_num.toString();
		
		wb_box.thumbnail_list.selectedIndex = present_page_num - 1;
		wb_box.thumbnail_list.scrollToIndex(wb_box.thumbnail_list.selectedIndex);
		
		wb_box.slide_list.selectedIndex = present_page_num - 1;
		wb_box.slide_list.scrollToIndex(wb_box.slide_list.selectedIndex);
		
		//retrieving file conversion output
		var image:String = wb_box.thumbnail_list.selectedItem.image;
		var imageExt:String = image.substring(image.lastIndexOf(".")+1, image.length);
		
		//retrieving slide type
		var slide_type:String = wb_box.thumbnail_list.selectedItem.type;
		myWbDebug("slide_type = " + slide_type);
		
		// clear existing video
		if (slidevideo) {
			is_play = true;
			playVideo();
		}
		wb_box.video.removeChildren();

		
		if (slide_type.toLowerCase() == "vector") { //slide SVG
			wb_box.slideimg.visible = false;
			wb_box.svg.visible = true;
			wb_box.video.visible = false;
			is_video_mode = false;
			
			
			//20130409
			wb_box.svg.addEventListener(SVGEvent.PARSE_COMPLETE, svgParseCompleteHandler);
			wb_box.svg.source = wb_box.thumbnail_list.selectedItem.image;
			wb_box.svg.horizontalCenter = 0;
			myWbDebug("vector file = " + wb_box.thumbnail_list.selectedItem.image);
		//	wb_box.svg.scaleX = 0.45;
		//	wb_box.svg.scaleY = 0.45;
			
			wb_box.svg.height = wb_box.wb_area.height - 2;	
			
			file_conversion_output = imageExt;
			
			// clear image source for runing slide prediction event on every changes
			wb_box.slideimg.source = null;
			slidevideo = null;
		}
		else if (slide_type.toLowerCase() == "video") {  //slide video
			wb_box.svg.visible = false;
			wb_box.slideimg.visible = false;
			wb_box.video.visible = true;
			wb_box.play.visible = true;
			wb_box.replay.visible = false;
			wb_box.wb_speaker.setStyle("icon", wb_speaker_on);
			is_wb_speaker = true;
			is_video_mode = true;
			is_first_play = true;
			is_first_metadata = true;
			
			var nsClient:Object = {};
			nsClient.onMetaData = ns_onMetaData;
			
			svideo = new Video();
		//	svideo.width = wb_box.video.width;
		//	svideo.height = wb_box.video.height;
			svideo.visible = true;
			wb_box.video.addChild(svideo);
			
			slidevideo = new NetStream(nc);  
			slidevideo.client = nsClient;
			slidevideo.bufferTime = VIDEO_BUFFER_TIME;
			slidevideo.addEventListener(NetStatusEvent.NET_STATUS, slideVideoNetStatusHandler);
			svideo.attachNetStream(slidevideo);	
			slidevideo.play(wb_box.thumbnail_list.selectedItem.image);
			
			// start video timer
			if (!video_timer.running) {
				wait(300);	// delay for correcting progressbar 
				video_timer.start();
				myWbDebug("start video timer");
			}
			//wait(500);
			//slidevideo.pause();
			//wb_box.video.source = wb_box.thumbnail_list.selectedItem.image;
			myWbDebug("video file = " + wb_box.thumbnail_list.selectedItem.image);
			
			// clear image source for runing slide prediction event on every changes
			wb_box.svg.source = null;
			wb_box.slideimg.source = null;
		}
		else {  // slide image
			wb_box.svg.visible = false;
			wb_box.slideimg.visible = true;
			wb_box.video.visible = false;
			is_video_mode = false;
			
			wb_box.slideimg.source = wb_box.thumbnail_list.selectedItem.image;
			myWbDebug("image file = " + wb_box.thumbnail_list.selectedItem.image);
			
			file_conversion_output = imageExt;
			
			// clear image source for runing slide prediction event on every changes
			wb_box.svg.source = null;
			slidevideo = null;
		}
		
		// update layout
		//if (slide_type !== old_slide_type) {
		validateWbLayout();
		validateWbLayout();
		
		//	old_slide_type = slide_type;
		//}
	}	
}

private function svgParseCompleteHandler(e:SVGEvent = null):void {
	myWbDebug("svgParseCompleteHandler");
	// calculate a scale
	if (wb_box.svg.visible) {
		var svgDoc:SVGDocument = wb_box.svg.svgDocument;
		var scaleX:Number = (wb_box.svg.width - 10) / svgDoc.width;  // 10 = gap
		var scaleY:Number = (wb_box.svg.height - 10) / svgDoc.height;
		wb_box.svg.scaleX = (scaleX < scaleY) ? scaleX : scaleY;
		wb_box.svg.scaleY = wb_box.svg.scaleX;
	}
}

private function slideVideoNetStatusHandler(event:NetStatusEvent):void	{
	try {
		switch (event.info.code) {
			case "NetStream.Play.Start" :
				// If the current code is Start, start the timer object.
				//video_timer.start();
				break;
			case "NetStream.Play.StreamNotFound" :
				Alert.show("Stream Not Found");
				break;
			case "NetStream.Play.Failed" :
				Alert.show("Play Failed");
				break;
			case "NetStream.Play.InsufficientBW" :
				Alert.show("Insufficient Bandwidth");
				break;
			case "NetStream.Buffer.Empty" :
				//Alert.show("NetStream.Buffer.Empty");
				if(slidevideo.time < video_duration-2){
					// 	video_ns.bufferTime=3;
					slidevideo.togglePause();
					slidevideo.resume();
				}
				break;
			case "NetStream.Buffer.Full" :
				// Alert.show("NetStream.Buffer.Full");
				break;
			case "NetStream.Buffer.Flush" :
				//Alert.show("NetStream.Buffer.Flush");
				break;
			case "NetStream.Failed" :
				Alert.show("NetStream Failed");
				break;
			case "NetStream.Play.Stop" :
				// If the current code is Stop or StreamNotFound, stop 
				// the timer object and play the next video_main in the playlist.
				//video_timer.stop();
				//cursor_timer.stop();
				//cursorImg.visible = false;
				break;
		}
	} catch (error:TypeError) {
		// Ignore any errors.
	}
}

private function ns_onMetaData(item:Object):void {
	video_duration = item.duration;
	wb_box.videoScrubber.maximum = video_duration;
	//for resizing the video
	if(is_first_metadata){  //second metadata trigger provide undefined values for height and width
		myWbDebug("video_duration: " + item.duration);
		myWbDebug("video_width: " + item.width);
		myWbDebug("video_height: " + item.height);
		video_width = item.width;
		video_height = item.height;
		svideo.height = wb_box.video.height - 4; // 4  for bottom padding
		svideo.width = svideo.height * (video_width/video_height);
		svideo.x = ( wb_box.video.width - svideo.width ) / 2;
	}	
	is_first_metadata = !is_first_metadata;
	
	// stop video first
	if (is_first_play) {
	 	wait(300);
		slidevideo.pause();
		is_first_play = false;
	}
	// clear busy mouse pointer
	CursorManager.removeBusyCursor();
}

public function playVideo (evnt:Event = null):void {
	if (!is_play) {
		myWbDebug("Play video");
		
		slidevideo.resume();
		so_lecture.send("doPlay", slidevideo.time);
		wb_box.play.setStyle("icon", pause_video);
	}
	else if (is_play) {
		myWbDebug("Pause video");

		slidevideo.pause();
		so_lecture.send("doPause", slidevideo.time);
		wb_box.play.setStyle("icon", play_video);	
	}
	is_play = !is_play;
	
}

public function doPlay (vtime:int):void {
	myWbDebug("Synchronize video play");
	if (!is_presenter){
		slidevideo.seek(vtime);
		slidevideo.resume();
	}
}

public function doPause (vtime:int):void {
	myWbDebug("Synchronize video pause ");
	if (!is_presenter){
		slidevideo.pause();
		slidevideo.seek(vtime);
		slidevideo.pause();
	}
}

public function replayVideo (evnt:Event = null):void {
	myWbDebug("Replay video");
	is_play = false;
	wb_box.play.visible = true;
	wb_box.replay.visible = false;
	wb_box.play.setStyle("icon", pause_video);
	
	wb_box.playbackProgressBar.setProgress(0, video_duration);
	wb_box.downloadProgressBar.setProgress(0, video_duration);
	//playVideo();
	slidevideo.pause();
	slidevideo.seek(0);
	slidevideo.resume();
	so_lecture.send("doReplay");	
	
	// start video timer
	if (!video_timer.running) {
		wait(100);	// delay for correcting progressbar 
		video_timer.start();
		myWbDebug("start video timer");
	}
}


public function doReplay():void {
	myWbDebug("Synchronize video replay ");
	if (!is_presenter){
		slidevideo.pause();
		slidevideo.seek(0);
		slidevideo.resume();
	}
}

private function videoScrubPause(evt:FlexEvent):void {
	myWbDebug("video scrubber pause");
	wb_box.play.visible = true;
	wb_box.replay.visible = false;
	is_play = false;
	
	slidevideo.pause();
	video_timer.stop();
	wb_box.play.setStyle("icon", play_video);
	slidevideo.seek(wb_box.videoScrubber.value);
}

private function videoScrubPlay(evt:FlexEvent):void {
	myWbDebug("video scrubber play");
	wb_box.play.visible = true;
	wb_box.replay.visible = false;
	is_play = true;
	
	slidevideo.seek(wb_box.videoScrubber.value);
	slidevideo.resume();
	video_timer.start();
	wb_box.play.setStyle("icon", pause_video);
	so_lecture.send("doPlay", wb_box.videoScrubber.value);

}

public function wbSpeakerStatus (evnt:Event = null):void {
	if (!is_wb_speaker) {
		myWbDebug("Turn-on whiteboard speaker");
		wb_video_st.volume = 0.75;
		slidevideo.soundTransform = wb_video_st;
		wb_box.wb_speaker.setStyle("icon", wb_speaker_on);
		so_lecture.send("doSpeakerStatusChange", true);	
	}
	else if (is_wb_speaker) {
		myWbDebug("Turn-off whiteboard speaker");
		wb_video_st.volume = 0;
		slidevideo.soundTransform = wb_video_st;
		wb_box.wb_speaker.setStyle("icon", wb_speaker_off);
		so_lecture.send("doSpeakerStatusChange", false);	
	}
	is_wb_speaker = !is_wb_speaker;
}

public function doSpeakerStatusChange (status:Boolean):void {
	myWbDebug("Synchronize speaker status  ");
	if (!is_presenter){
		if(status) {
			wb_video_st.volume = 1.0;
			slidevideo.soundTransform = wb_video_st;
			myWbDebug("Turn-on speaker");
		}
		else if (!status) {
			wb_video_st.volume = 0;
			slidevideo.soundTransform = wb_video_st;
			myWbDebug("Turn-off speaker");
		}
	}
}

// Predict the next slide for background downloading
private function nextSlidePrediction1(event:SVGEvent):void {
	nextSlidePrediction(null);
}

private function nextSlidePrediction(event:Event):void {
	myWbDebug("nextSlidePrediction : old_page_num = " + old_page_num + ", present_page_num = " + present_page_num);
	
	// clear cursor
	CursorManager.removeBusyCursor();
	
	if (image_files != null) {
		var predict_page_num:Number = 0;
		// forward prediction
		if (old_page_num <= present_page_num) {
			if (present_page_num < last_page_num) {
				predict_page_num = present_page_num + 1;	
			}
		}
		// backward prediction
		else {
			if (present_page_num > 1) {
				predict_page_num = present_page_num - 1;	
			}
		}
		
		// skip prediction for video content
		if (image_files.getItemAt(predict_page_num - 1).type.toLowerCase() != "video") {
			if (predict_page_num > 0 && predict_page_num <= last_page_num) {
				myWbDebug("next prediction : predict_page_num = " + predict_page_num + ", image = " + image_files.getItemAt(predict_page_num - 1).image);
				
				// load image (to broser's cache)
				predictRequest = new URLRequest(image_files.getItemAt(predict_page_num - 1).image);
				
				if (predictLoader == null) {
					predictLoader = new URLLoader();
				}
				predictLoader.addEventListener(Event.COMPLETE, onPredictionComplete);
				predictLoader.load(predictRequest);
			}
		}
	}
}

private function onPredictionComplete(event:Event):void {
	myWbDebug("predict image download has been completed");
}

// check current lecture mode from the server
private function checkLectureMode(mode:int):void {
	myWbDebug("checkLectureMode : mode = " + mode);
	// mode = 1 -> cursor mode
	// mode = 2 --> pen mode
	cursorBoolean = true;
	if (mode != MODE_CURSOR) {
		cursorBoolean = false;
		updateData(cursorBoolean);
	}
	penBoolean = !cursorBoolean;
	wb_box.pen_btn.enabled = cursorBoolean;
	wb_box.cursor_btn.enabled = !cursorBoolean;
}

// save current data to file at the server 
private function saveLoadPageContent(): void {
	if (is_presenter || is_chairman) {
		myWbDebug("saveLoadPageContent : contentID - " + contentID + ", old_page_num - " + old_page_num+ ", present_page_num - " + present_page_num);
		if (CursorManager.currentCursorID == 0) { 
			CursorManager.setBusyCursor();
		}
		
		// set background image of new slide as the first piority
		so_meeting.send("setSlideNumber", present_page_num, old_page_num);
		myWbDebug("SO.send : setSlideNumber");
		
		//keep page states and annotation data
		nc.call('saveLoadData', new Responder(syncPageData), old_page_num, present_page_num, scrollbar_x, scrollbar_y, wb_box.wb_container.scaleX, zoom_value);
		myWbDebug("NC.call : saveLoadData");
		
		// synchronize lecture client slide
		if (ENABLE_LECTURE_CLIENT) {
			so_lecture.send("setSlideNumber", present_page_num, old_page_num);
			myWbDebug("SO.send : setSlideNumber - for lecture");
		}
	}
}

// save current data to file at the server 
private function savePageContent(): void {
	if (is_presenter || is_chairman) {
		myWbDebug("savePageContent : contentID - " + contentID + " ; present_page_num - " + present_page_num);
		//keep page states and annotation data
		nc.call('keepData', null, scrollbar_x, scrollbar_y, wb_box.wb_container.scaleX, zoom_value);
		myWbDebug("NC.call : keepData");
	}
}

// load new data from the server 
private function loadPageContent(): void {
	if (is_presenter) {
		myWbDebug("loadPageContent : contentID - " + contentID + " ; present_page_num - " + present_page_num);
		// set background image of new slide as the first piority
		so_meeting.send("setSlideNumber", present_page_num);
		myWbDebug("SO.send : setSlideNumber");
		
		// retrieve page state
		nc.call('loadData', new Responder(syncPageData), present_page_num);
		myWbDebug("NC.call : loadData");
	}
}

private function syncPageData(ret:Boolean): void {
	myWbDebug("NC.responder : loadData");
	if (ret) {
		so_meeting.send("updateData", cursorBoolean);
		myWbDebug("SO.send : updateData");
		//nc.call('loadPredictData', null);
		//myWbDebug("NC.call : loadPredictData");
	}
}
//--------------------Go and Return pages of Whiteboard--------------//	
// go to the previous page
private function goPrevious(evt:Event): void {
	if (present_page_num > 1) {
		myWbDebug("goPrevious");
		if (is_offline_mode) {
			//set page number
			present_page_num = present_page_num - 1;
			wb_box.present_page.text = present_page_num.toString();	
			
			showOfflinePage();
			clearDrawing(null);
		}
		else {
			//set page number
			old_page_num = present_page_num;
			present_page_num = present_page_num - 1;
			
			saveLoadPageContent();
		}
	}
	dragBoolean = false;
	if (cursorBoolean = !penBoolean) {
		wb_box.cursor_btn.enabled = false;
	}
	wb_box.dragging.enabled = false;
	processZoomFit ();
	if(isA4Zoom) {
		processZoomA4();
	} 
	updateNaviButtons();
}

// go to the next page
  private function goNext(evt:Event): void {
	if(present_page_num < last_page_num){
		myWbDebug("goNext");
		if (is_offline_mode) {
			//set page number
			if (present_page_num < last_page_num) {
				present_page_num = present_page_num + 1;		
			} else {
				present_page_num = present_page_num;		
			}
			wb_box.present_page.text = present_page_num.toString();	
			
			showOfflinePage();
			clearDrawing(null);
		}
		else {
			//set page number
			old_page_num = present_page_num;
			if (present_page_num < last_page_num) {
				present_page_num = present_page_num + 1;		
			} else {
				present_page_num = present_page_num;		
			}
			
			saveLoadPageContent();
			
		}
	}
	dragBoolean = false;
	if (cursorBoolean = !penBoolean) {
		wb_box.cursor_btn.enabled = false;
	}
	wb_box.dragging.enabled = false;
	processZoomFit ();
	if(isA4Zoom) {
		processZoomA4();
	} 
	updateNaviButtons();
} 

/////////////////
private function goLast (evt:Event):void {
	if (present_page_num < last_page_num) {
		myWbDebug("goLast");
		if (is_offline_mode) {
			//set page number
			present_page_num = last_page_num;
			wb_box.present_page.text = present_page_num.toString();	
			
			showOfflinePage();
			clearDrawing(null);
		}
		else {
			//set page number
			old_page_num = present_page_num;
			present_page_num = last_page_num;	
			
			saveLoadPageContent();
		}
	}
	dragBoolean = false;
	if (cursorBoolean = !penBoolean) {
		wb_box.cursor_btn.enabled = false;
	}
	wb_box.dragging.enabled = false;
	processZoomFit ();
	if(isA4Zoom) {
		processZoomA4();
	} 
	updateNaviButtons();
}

private function goFirst (evt:Event):void {
	if (present_page_num > 1) {
		myWbDebug("goFirst");
		if (is_offline_mode) {
			//set page number
			present_page_num = 1;
			wb_box.present_page.text = present_page_num.toString();	
			
			showOfflinePage();
			clearDrawing(null);
		}
		else {
			//set page number
			old_page_num = present_page_num;
			present_page_num = 1;	
			
			saveLoadPageContent();
		}
	}
	dragBoolean = false;
	if (cursorBoolean = !penBoolean) {
		wb_box.cursor_btn.enabled = false;
	}
	wb_box.dragging.enabled = false;
	processZoomFit ();
	if(isA4Zoom) {
		processZoomA4();
	} 
	updateNaviButtons();
}

// jump to the selected page
private function goToPage(event:ListEvent): void {
	var selectedIndex:Number = event.currentTarget.selectedIndex;
	
	if (present_page_num != (selectedIndex + 1)) {
		myWbDebug("goToPage : " + (selectedIndex + 1));
		if (is_offline_mode) {
			//set page number
			present_page_num = selectedIndex + 1;
			wb_box.present_page.text = present_page_num.toString();	
			
			showOfflinePage();
			clearDrawing(null);
		}
		else {
			//set page number
			old_page_num = present_page_num;
			present_page_num = selectedIndex + 1;
			
			saveLoadPageContent();
		}
	}
	dragBoolean = false;
	if (cursorBoolean = !penBoolean) {
		wb_box.cursor_btn.enabled = false;
	}
	wb_box.dragging.enabled = false;
	processZoomFit ();
	if(isA4Zoom) {
		processZoomA4();
	} 
	updateNaviButtons();
}

/**
 *  Online Presenter Mode Function 
 */
private function presenter_change(evt:Event): void {
	myWbDebug("presenter_change");
	
	is_presenter = wb_box.presentor_action.selected;
	myWbDebug("is_presenter = " + is_presenter);
	wb_box.play.visible = true;
	cursorBoolean = true; // start with cursor mode
	penBoolean = !cursorBoolean;
	wb_box.function_mode_btn.enabled = is_presenter;
	wb_box.pen_btn.enabled = cursorBoolean;
	wb_box.cursor_btn.enabled = !cursorBoolean;
	wb_box.cursorImg.visible = false;
	
	nc.call("setPageState", null, 0, 0, 1.0, 0);
	myWbDebug("NC.call : setPageState");
	nc.call("setLectureMode", null, (cursorBoolean ? MODE_CURSOR : MODE_ANNOTATION)); // save a lecture mode at the server
	myWbDebug("NC.call : setLectureMode");
	
	// update presenter video status for lecture
	if (ENABLE_LECTURE_CLIENT) {
		if (is_presenter) {
			if (is_cam_on) {
				nc.call("setPresenterID", null, clientID, true);
				myWbDebug("NC.call : setPresenterID");
				so_lecture.send("updateVideoData", clientID, true);
				myDebug("SO_lecture.send : updateVideoData - camera on");
			} else {
				nc.call("setPresenterID", null, clientID, true);
				myWbDebug("NC.call : setPresenterID");
				so_lecture.send("updateVideoData", clientID, false);
				myDebug("SO_lecture.send : updateVideoData - camera off");
			}
		} else {
			nc.call("setPresenterID", null, 0, false);
			myWbDebug("NC.call : setPresenterID");
			so_lecture.send("updateVideoData", 0, false);
			myDebug("SO_lecture.send : updateVideoData - camera off");
		}
	}
	
	// reset all interface
	so_meeting.send("resetPage");
	myWbDebug("SO.send : resetPage");
	if (is_presenter && !is_offline_mode) {
		so_meeting.send("updateData", cursorBoolean);
		myWbDebug("SO.send : updateData");
	}
	so_meeting.send("updateUserListStatus", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
	myWbDebug("SO.send : updateUserListStatus");
	
	// local update
	updateWbButtons();
	updateNaviButtons();
	validateWbLayout();
	
	// show the slide title if it is not already shown by the offline option
	if (!is_offline_mode) {
		toggleSlideTitle();
	}
}

private function checkPresenter():void {
	myWbDebug("checkPresenter");
	wb_box.presentor_action.enabled = true;
	for(var i:int = 0; i < meetingUsers.length;i++) {
		if(meetingUsers[i].presenter) {
			myWbDebug("checkPresenter : found presenter id - " + meetingUsers[i].clientid + "; myID - " + clientID);
			if (meetingUsers[i].clientid != clientID) {
				wb_box.presentor_action.enabled = false;
				wb_box.play.visible = false;
			}
			break;
		}
	}
}

private function KeyMove(e:KeyboardEvent):void {
	if (is_presenter || is_offline_mode) {
		if (e.keyCode == 39 || e.keyCode == 40) {  //  KeyBoard 40: DOWN ** KeyBoard 39: Right
			goNext(null);
		} else if (e.keyCode == 37 || e.keyCode == 38) {  //  KeyBoard 38: UP ** KeyBoard 37: Left
			goPrevious(null);
		} else if (e.keyCode == 36) {  //  KeyBoard 36: HOME
			goFirst(null);
		} else if (e.keyCode == 35) {  //  KeyBoard 36: END
			goLast(null);
		}
	}
}

private function KeyZoom (e:KeyboardEvent):void {
	if (is_presenter || is_offline_mode) {
		if (e.keyCode == 107 && e.ctrlKey){   // 107 : +
			zoomIn();
		}	else if (e.keyCode == 187 && e.ctrlKey && e.shiftKey){   
			zoomIn();
		}else if (e.keyCode == 109 && e.ctrlKey){  // 109 : -
			zoomOut();
		}else if (e.keyCode == 189 && e.ctrlKey){   
			zoomOut();
		}
	}
}
 
/* check the presenter right */
private function isPresenter(clientid:int):Boolean {
	myWbDebug("isPresenter");
	is_presenter = false;
	for(var i:int = 0; i < meetingUsers.length;i++) {
		if(meetingUsers[i].clientid == clientid && meetingUsers[i].presenter) {
			myWbDebug("isPresenter : found presenter id " + meetingUsers[i].clientid);
			is_presenter = true;
			break;
		}
	}
	return is_presenter;
}


/**
 *  Offline Mode Function 
 */
private function offlineMode_change(evt:Event): void {
	myWbDebug("offlineMode_change");
	
	is_offline_mode = wb_box.offline_mode.selected;
	myWbDebug("is_offline_mode = " + is_offline_mode);
	wb_box.dragging.enabled = true;
	// retrieve existing draw data after swithed from offline mode
	if (!is_offline_mode) {
		processZoomFit();
		// update local data
		nc.call("getRoomState", new Responder(setRoomState));
		myWbDebug("NC.call : getRoomState");
		wb_box.cursorImg.visible = false;  // hide the cursor
	}
	else {
		this.resetLayer();
	}
	
	updateWbButtons();
	updateNaviButtons();
	// show the slide title if it is not already shown by the presenter option
	if (!is_presenter) {
		toggleSlideTitle();
	}
}

/**
 * add new blank page 
 */
private function addBlankPage(evt:Event): void {
	myWbDebug("addBlankSlide");
	
	// generate file name
	var ctime:Number = new Date().getTime();
	var img_src:String = ctime + "-blank.png";
	
	// create file ate server
	nc.call("createBlankFile", null, contentID, img_src, false);
	myWbDebug("NC.call : createBlankFile");
	
	var image:String = contentID + "/working/files/" + img_src;
	var thumb:String = contentID + "/working/files/thumb/" + img_src;
	var newPage:Object = {page:0, title:"", image:image, thumb:image, image_src:img_src, description:""};
	
	var idx:int = wb_box.thumbnail_list.selectedIndex+1;
	image_files.addItemAt(newPage, idx);
	wb_box.thumbnail_list.selectedIndex = idx;
	present_page_num = present_page_num + 1;

	
	// update content_description.xml
	saveContent();
	wait(300);
	loadPageContent();
	// Update to other users
	so_meeting.send("loadContentData", contentID);
	myWbDebug("SO.send : loadContentData");
	
	Alert.show(resourceManager.getString('meeting_messages', 'alert_new_blank_slide_added'));
}

///////////////////////Remove Slides from files directory at server side////////
private function confirmRemoveSlide(evt:Event): void {
	Alert.show(resourceManager.getString('meeting_messages', 'alert_delete_current_slide'),
		resourceManager.getString('meeting_messages', 'alert_system'),
		Alert.OK|Alert.CANCEL,
		this, removeSlide);
}

private function removeSlide(evt:CloseEvent): void {
	if (evt.detail == Alert.OK && wb_box.thumbnail_list.selectedIndex != -1) {
		myWbDebug("removeSlide");
		var idx:int = wb_box.thumbnail_list.selectedIndex;
		image_files.removeItemAt(idx);
		
		// update content_description.xml
		saveContent();
		wait(300);
		loadPageContent();
		// Update to other users
		so_meeting.send("loadContentData", contentID);
		myWbDebug("SO.send : loadContentData");
		
		Alert.show(resourceManager.getString('meeting_messages', 'alert_slide_deleted'));
	}
}

private function confirmRemoveAllSlides(evt:Event): void {
	Alert.show(resourceManager.getString('meeting_messages', 'alert_delete_all_slides'),
		resourceManager.getString('meeting_messages', 'alert_system'),
		Alert.OK|Alert.CANCEL,
		this, removeAllSlides);
}

private function removeAllSlides(evt:CloseEvent): void {
	if (evt.detail == Alert.OK && wb_box.thumbnail_list.selectedIndex != -1) {
		myWbDebug("removeAllSlides");
		image_files.removeAll();
		
		// update content_description.xml
		saveContent();
		wait(300);
		loadPageContent();
		// Update to other users
		so_meeting.send("loadContentData", contentID);
		myWbDebug("SO.send : loadContentData");
		Alert.show(resourceManager.getString('meeting_messages', 'alert_all_slides_deleted'));
	}
}

// update the metadata
private function saveContent():void {
	myWbDebug("saveContent");
	if (is_presenter) {
		if (CursorManager.currentCursorID == 0) { 
			CursorManager.setBusyCursor();
		}
		
		if (image_files.length > 0) {
			myWbDebug("remove by slide");
			for (var i:int = 0; i < image_files.length; i++) {
				var page:int = image_files.getItemAt(i).page;
				var title:String = image_files.getItemAt(i).title;
				var image:String = image_files.getItemAt(i).image_src;
				var description:String = image_files.getItemAt(i).description;
				
				nc.call("setEditorData", null, ((i == 0) ? true : false), page, title, image, description);
				myWbDebug("NC.call : setEditorData");
			}
		}
		else {
			myWbDebug("remove all");
			nc.call("clearEditorData", null, contentID);
			myWbDebug("NC.call : clearEditorData");
		}
		// create course 
		nc.call("saveEditorTemplate", null, contentID, false, false);
		myWbDebug("NC.call : saveEditorTemplate");
		
		CursorManager.removeBusyCursor();
	}
}

private function confirmRestoreOriginalContent(evt:Event): void {
	Alert.show(resourceManager.getString('meeting_messages', 'alert_restore_original_version'),
		resourceManager.getString('meeting_messages', 'alert_system'),
		Alert.OK|Alert.CANCEL,
		this, restoreOriginalContent);
}

private function restoreOriginalContent(evt:CloseEvent): void {
	if (evt.detail == Alert.OK) {
		myWbDebug("restoreOriginalContent");
		
		nc.call("setWorkingData", null, contentID);
		wait(300);
		present_page_num = 1;
		loadPageContent();
		// Update to other users
		so_meeting.send("loadContentData", contentID);
		myWbDebug("SO.send : loadContentData");
		Alert.show(resourceManager.getString('meeting_messages', 'alert_original_content_restored'));
	}
}

private function confirmRestoreModifiedContent(evt:Event): void {
	Alert.show("Are you sure to restore the modified content?",
		resourceManager.getString('meeting_messages', 'alert_system'),
		Alert.OK|Alert.CANCEL,
		this, restoreModifiedContent);
}

private function restoreModifiedContent(evt:CloseEvent): void {
	if (evt.detail == Alert.OK) {
		myWbDebug("restoreModifiedContent");
		
		nc.call("restoreModifiedData", null, contentID);
		wait(300);
		present_page_num = 1;
		loadPageContent();
		// Update to other users
		so_meeting.send("loadContentData", contentID);
		myWbDebug("SO.send : loadContentData");
		Alert.show("Modified Content Restored");
	}
}


/**
 * Video Embedded Controls
 **/
private function formatTime(value:int):String
{
	var result:String = (value % 60).toString();
	if (result.length == 1)
		result = Math.floor(value / 60).toString() + ":0" + result;
	else 
		result = Math.floor(value / 60).toString() + ":" + result;
	return result;
}

private function videoTimerHandler(event:TimerEvent):void {
	// show playback progress
	var tmpPos:int = slidevideo.time;
	wb_box.video_running_time.text = formatTime(tmpPos);
	wb_box.video_time_duration.text = " / " + formatTime(video_duration);
	wb_box.playbackProgressBar.setProgress(tmpPos, video_duration);
	wb_box.videoScrubber.value = tmpPos;
		
	// show buffer progress
	var tmpBuf:int = tmpPos + slidevideo.bufferLength;
	tmpBuf = (tmpBuf > video_duration) ? video_duration : tmpBuf;
	wb_box.downloadProgressBar.setProgress(tmpBuf, video_duration);
	
	//myWbDebug("video duration - " + video_duration + " ; playtime - " + tmpPos);
	
	if (tmpPos == video_duration && tmpPos != 0) {
		video_timer.stop();
		wb_box.play.visible = false;
		wb_box.replay.visible = true;
	}
}

/**
 * Text Layout Framework (TLF) for Real-time Collaborative Text Editing
 * */

private function updateText(evt:Event):void {
	if(is_presenter){	
		so_meeting.send("doUpdateText", wb_box.editor.textFlowMarkup);
		myWbDebug("S.O. Send - Synchronize text update.");
	}
}

public function doUpdateText (textString:String):void {
	if (!is_presenter){
		wb_box.editor.textFlowMarkup = textString;
		myWbDebug("S.O. Recv - Synchronize text update ");
	}
}

private function modeToggle(evt:Event): void {
	if(!textBoolean){
		myWbDebug("START TLF Real-time Collaborative Text Editing");
		wb_box.text_editor_viewport.visible = true;
		wb_box.wb_viewport.visible = false;
		wb_box.page_tool.visible = false;
		wb_box.draw_tool1.enabled = false;
		wb_box.draw_tool2.enabled = false;
		wb_box.draw_mode.enabled = false;
		wb_box.upload_tool.enabled = false;
		wb_box.function_mode_btn.setStyle("icon", slide_presentation);
		wb_box.function_mode_btn.toolTip = resourceManager.getString('meeting_messages', 'tooltip_multimedia_slide_presentation');
		so_meeting.send("doTextMode", true);
		myWbDebug("S.O. Send - doTextMode ");
	} else if (textBoolean){
		myWbDebug("END TLF Real-time Collaborative Text Editing");
		wb_box.text_editor_viewport.visible = false;
		wb_box.wb_viewport.visible = true;
		wb_box.page_tool.visible = true;
		wb_box.draw_tool1.enabled = true;
		wb_box.draw_tool2.enabled = true;
		wb_box.draw_mode.enabled = true;
		wb_box.upload_tool.enabled = true;
		wb_box.function_mode_btn.setStyle("icon", text_editor);
		wb_box.function_mode_btn.toolTip = resourceManager.getString('meeting_messages', 'tooltip_real_time_text_editor');
		so_meeting.send("doTextMode", false);
		myWbDebug("S.O. Send - doTextMode ");
	}
	textBoolean = !textBoolean;
}

public function doTextMode (status:Boolean):void {
	if (!is_presenter){
		if(status){
			wb_box.text_editor_viewport.visible = true;
			wb_box.wb_viewport.visible = false;
			wb_box.page_tool.visible = false;
			myWbDebug("S.O. Recv - START TLF text editing ");
		} else if(!status) {
			wb_box.text_editor_viewport.visible = false;
			wb_box.wb_viewport.visible = true;
			wb_box.page_tool.visible = true;
			myWbDebug("S.O. Recv - END TLF text editing ");
		}
	}
}


/** 
 * debugging
 **/
private function myWbDebug(dbgMsg:String):void {
	if (WBDEBUG) {
		ExternalInterface.call("console.log", "--WBDEBUG-- " + dbgMsg);
	}
}
