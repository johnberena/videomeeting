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

private static var AUTO_RESIZE_APP:Boolean = false;

// define the interface mode
private static var UI_MODE_DEFAULT:int = 1; // default mode (small video : whiteboard)
private static var UI_MODE_SMALL_VIDEO:int = 2; // smail video
private static var UI_MODE_WHITEBOARD:int = 3; // whiteboard 
private static var UI_MODE_WIDE_VIDEO:int = 4; // wide video
private static var UI_MODE_FULL_SCREEN:int = 5; // full screen mode
private static var UI_MODE_FULL_SCREEN_VIDEO:int = 6; // full screen video
private static var UI_MODE_FULL_SCREEN_PRESENTATION:int = 7; // full screen presentation

private var current_ui_mode:int = UI_MODE_DEFAULT;
private var global_app_width:int = 100;
private var global_app_height:int = 100;
private var is_full_screen:Boolean = false;
private var tmpTimeOutID:uint;//Timeout for layout changing

private var is_video_mode:Boolean = false;
private var svideo:Video = null;

// full screen handler
private function fullScreenHandler(evt:FullScreenEvent):void {
	
	switch (this.systemManager.stage.displayState) {
		case StageDisplayState.FULL_SCREEN_INTERACTIVE:
			is_full_screen = true;
			
			tgMainLayout.enabled = false;
			tgVideoLayout.enabled = false;
			tgWhiteboardLayout.enabled = false;
			tgBigVideoLayout.enabled = false;
			
			// change to full screen layout
			changeInterfaceLayout(UI_MODE_FULL_SCREEN);
			
			tgFullVideoLayout.toolTip = resourceManager.getString('meeting_messages', 'tooltip_full_screen_off');
			break;
		default:
			is_full_screen = false;
			tgMainLayout.enabled = true;
			tgVideoLayout.enabled = true;
			tgWhiteboardLayout.enabled = true;
			tgBigVideoLayout.enabled = true;
			
			if (current_ui_mode == UI_MODE_FULL_SCREEN_PRESENTATION) {
				// return to whiteboard
				if(isA4Zoom){
					wb_box.wb_container.scaleX = 1;
					wb_box.wb_container.scaleY = 1;
					wbArea.validateNow();
					isA4Zoom = false;
				}
				changeInterfaceLayout(UI_MODE_WHITEBOARD);
			}
			else {
				// return to wide screen
				changeInterfaceLayout(UI_MODE_WIDE_VIDEO);
			}
			changePanelScale();
			tgFullVideoLayout.toolTip = resourceManager.getString('meeting_messages', 'tooltip_full_screen_on');
			break;
	}
}

// toggle a display mode
private function toggleFullScreen(evt:Event = null):void {
	myDebug("toggleFullScreen");
	try {
		switch (this.systemManager.stage.displayState) {
			case StageDisplayState.FULL_SCREEN_INTERACTIVE:
				/* If already in full screen mode, switch to normal mode. */
				this.systemManager.stage.displayState = StageDisplayState.NORMAL;
				tgFullVideoLayout.toolTip = resourceManager.getString('meeting_messages', 'tooltip_full_screen_on');
				if(isA4Zoom){
					wb_box.wb_container.scaleX = 1;
					wb_box.wb_container.scaleY = 1;
					wbArea.validateNow();
					isA4Zoom = false;
				}
				break;
			default:
				/* If not in full screen mode, switch to full screen mode. */
				this.systemManager.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
			//	this.systemManager.stage.displayState = StageDisplayState.FULL_SCREEN;
				break;
		}
	} catch (err:SecurityError) {
		myDebug("Full-screen Error");
	}
}

private function forChangingInterfaceLayout(layout:int = 0):void {
	layout = (layout == 0) ? UI_MODE_DEFAULT : layout;
	if (layout != current_ui_mode) {
		myDebug("forChangingInterfaceLayout");
		if((is_presenter || is_admin) && is_shared_display){
			so_meeting.send("changeInterfaceLayout", layout);
			myDebug("SO.send : changeInterfaceLayout");
		} else {
			changeInterfaceLayout(layout);
		}
	}
}

public function changeInterfaceLayout(layout:int = 0):void {
	myDebug("SO.recv : changeInterfaceLayout");
	
	// default values
	meetingPanel.setStyle("skinClass", skins.webelsPanelSkin);
	
	layoutControl.visible = true;
	meetingArea.visible = true;
	whiteboardArea.visible = true;
	userArea.visible = true;
	devicesQuality.visible = true;
	detailArea.visible = true;
	
	layoutControl.width = 28;
	userArea.height = 24;
	devicesQuality.height = 24;
	whiteboardArea.chairman_tool.height = 25;
	whiteboardArea.tool_panel.height = 36;
	whiteboardArea.chairman_tool.visible = true;
	whiteboardArea.tool_panel.visible = true;
	whiteboardArea.exit_full_screen.visible = false;
	whiteboardArea.contentInfoFullscreen.visible = false;

	
	// restore video scale
	for (var i:int = 0; i < MAX_DISPLAYS; i++) {
		displayObj[i].window.visible = true;
		if (displayObj[i].connected) {
			displayObj[i].vid.scaleX = 1;
			displayObj[i].vid.scaleY = 1;
		}
	}
	
	layout = (layout == 0) ? UI_MODE_DEFAULT : layout;
	if (layout == UI_MODE_FULL_SCREEN) {
		layout = (current_ui_mode == UI_MODE_WHITEBOARD) ? UI_MODE_FULL_SCREEN_PRESENTATION : UI_MODE_FULL_SCREEN_VIDEO;
	}

	switch (layout) {
		// only small video
		case UI_MODE_SMALL_VIDEO:
			myDebug("ui_layout : UI_MODE_SMALL_VIDEO");
			// main object
			global_app_width = 300; //300
			global_app_height = 668; //685;
			
			videoSection.addElement(controlArea);
			controlArea.addElement(videoControlGroup);
			controlArea.addElement(adminControlGroup);
			
			meetingPanel.width = global_app_width;
			meetingPanel.height = global_app_height;
			// update layout
			meetingPanel.validateNow();
			meetingArea.validateNow();
			meetingArea.width = 266;  //266
			meetingArea.percentHeight = 100; //610
			meetingArea.x = layoutControl.width;
			
			detailArea.percentHeight = 100;
			detailArea.width = 266;
			
			wbArea.visible = false;
			
			tgFullVideoLayout.enabled = false;
			
			changeToSmallVideo();
			break;
		// only whiteboard
		case UI_MODE_WHITEBOARD:
			myDebug("ui_layout : UI_MODE_WHITEBOARD");
			// main object
			global_app_width = 1028;  //940
			global_app_height = 668; //685;
			
			meetingPanel.width = global_app_width;
			meetingPanel.height = global_app_height;
			
			videoSection.addElement(controlArea);
			controlArea.addElement(videoControlGroup);
			controlArea.addElement(adminControlGroup);
			
			meetingArea.visible = false;
			wbArea.visible = true;
			
			// update layout
			meetingPanel.validateNow();
			
			whiteboardArea.percentWidth = 100;
			whiteboardArea.percentHeight = 100;
			whiteboardArea.page_tool.visible = false;
			wb_box.hidelist_btn.visible = true;
			
			meetingPanel.validateNow();
			
			// control the slide list 
			if (is_presenter || is_offline_mode) {
				whiteboardArea.slide_list_box.visible = true;
				whiteboardArea.slide_list_box.width = 146;
				whiteboardArea.page_tool2.visible = !whiteboardArea.slide_list_box.visible;
				whiteboardArea.hidelist_btn.visible = whiteboardArea.slide_list_box.visible;
			}
			else {
				whiteboardArea.slide_list_box.visible = false;
				whiteboardArea.page_tool2.visible = whiteboardArea.slide_list_box.visible;
				whiteboardArea.hidelist_btn.visible = whiteboardArea.slide_list_box.visible;
			}
			
			// update layout (double calls for correctly update)
			validateWbLayout();
			validateWbLayout();
			updateData(cursorBoolean);
			
			// focus the whitebaord area to activate the key event
			meetingPanel.focusManager.setFocus(whiteboardArea.wb_viewport);
			
			tgFullVideoLayout.enabled = true;
			
			break;
		// only wide video
		case UI_MODE_WIDE_VIDEO:
			myDebug("ui_layout : UI_MODE_WIDE_VIDEO");
			// main object
			global_app_width = 728; //1028
			global_app_height = 668; //680
			
			meetingPanel.width = global_app_width;
			meetingPanel.height = global_app_height;	
			meetingPanel.validateNow();
			wbArea.visible = false;
			
			myDebug("ui_layout : UI_MODE_WIDE_VIDEO : Stage 1");
			
			if(current_ui_mode != UI_MODE_FULL_SCREEN_VIDEO){
				videoSection.removeElement(controlArea);
				userArea.addElement(adminControlGroup);
				adminControlGroup.left = 350;
				adminControlGroup.top = 0;
				devicesQuality.addElement(videoControlGroup);
				videoControlGroup.left = 350;
				videoControlGroup.top = 0;
			}
	//		fileSharingGroup.removeElement(progressBar);
	//		fileUploadGroup.addElement(progressBbar);
			
			myDebug("ui_layout : UI_MODE_WIDE_VIDEO : Stage 2");
			
			// update layout
			meetingArea.width = global_app_width - layoutControl.width - 6;// 6 - pad
			meetingArea.height = global_app_height;
			meetingArea.x = layoutControl.width;
			meetingArea.visible = true;
			
			
			meetingArea.validateNow();
			
			myDebug("ui_layout : UI_MODE_WIDE_VIDEO : Stage 3");
			
			tgFullVideoLayout.enabled = true;
			
			changeToWideVideo();
			break;
		// full screen (video only)
		case UI_MODE_FULL_SCREEN_VIDEO:
			// main object
			myDebug("ui_layout : UI_MODE_FULL_SCREEN_VIDEO");
			global_app_width = FlexGlobals.topLevelApplication.width;
			global_app_height = FlexGlobals.topLevelApplication.height;
			
			meetingPanel.width = global_app_width;
			meetingPanel.height = global_app_height;
			// update layout
			meetingPanel.validateNow();
			meetingArea.validateNow();
			meetingArea.width = global_app_width - layoutControl.width;
			meetingArea.height = global_app_height;
			meetingArea.x = layoutControl.width;
			userArea.height = 0;
			devicesQuality.height = 0;
			
			whiteboardArea.visible = false;
			userArea.visible = false;
			devicesQuality.visible = false;
			detailArea.visible = false;
			
			tgFullVideoLayout.enabled = true;
			
			changeToFullScreenVideo();
			break;
		// full screen (presentation only)
		case UI_MODE_FULL_SCREEN_PRESENTATION:
			myDebug("ui_layout : UI_MODE_FULL_SCREEN_PRESENTATION");
			meetingPanel.setStyle("skinClass", skins.webelsPanelSkinNoTitle);
			// return to the regular mode
			if (is_presenter) {
				zoomFit(null);
			}
			
			// main object
			global_app_width = FlexGlobals.topLevelApplication.width;
			global_app_height = FlexGlobals.topLevelApplication.height;
			
			meetingPanel.width = global_app_width;
			meetingPanel.height = global_app_height;
			userArea.height = 0;
			layoutControl.width = 0;
			meetingArea.width = 0;
			whiteboardArea.x = 0;
			whiteboardArea.y = 0;
			whiteboardArea.chairman_tool.height = 0;
			//whiteboardArea.tool_panel.height = 0;
			whiteboardArea.chairman_tool.visible = false;
			//whiteboardArea.tool_panel.visible = false;
			whiteboardArea.exit_full_screen.visible = true;
			
			userArea.visible = false;
			layoutControl.visible = false;
			meetingArea.visible = false;
			// update layout
			meetingPanel.validateNow();
			meetingArea.validateNow();
			
			tgFullVideoLayout.enabled = true;
			
			changeToFullScreenPresentation();
			break;
		// small video + whiteboard
		default :
			myDebug("ui_layout : DEFAULT");
			global_app_width = 1100; //1100
			global_app_height = 668; //685;
			
			videoSection.addElement(controlArea);
			controlArea.addElement(videoControlGroup);
			controlArea.addElement(adminControlGroup);
			//myDebug("controlArea NumElements = " + controlArea.numElements);
			
			meetingPanel.width = global_app_width;
			meetingPanel.height = global_app_height;
			meetingPanel.validateNow();
			
			meetingArea.width = 266;  //266
			meetingArea.percentHeight = 100; //610
			meetingArea.includeInLayout = true;
			meetingArea.visible = true;
			
			meetingArea.validateNow();
			
			detailArea.percentHeight = 100;
			detailArea.width = 266;
			
			wbArea.visible = true;
			whiteboardArea.width = 800;
			whiteboardArea.percentHeight = 100;
			whiteboardArea.page_tool.visible = true;
			whiteboardArea.page_tool.height = 80;
			whiteboardArea.slide_list_box.visible = !whiteboardArea.page_tool.visible;
			whiteboardArea.page_tool2.visible = !whiteboardArea.page_tool.visible;
			wb_box.hidelist_btn.visible = false;
			tgFullVideoLayout.enabled = false;
			
			// update layout (double calls for correctly update)
			validateWbLayout();
			validateWbLayout();
			changeToSmallVideo();
			updateData(cursorBoolean);
			break;
	}
	current_ui_mode = layout;
	myDebug("current_ui_layout : " + current_ui_mode);
	
	if (ExternalInterface.available) {
		//ExternalInterface.call("resizeOuterTo", FlexGlobals.topLevelApplication.width, FlexGlobals.topLevelApplication.height);
		ExternalInterface.call("resizeOuterTo", meetingPanel.width + 2, meetingPanel.height + 2);
	}
	else {
		myDebug("Wrapper not available");
	}
}

// calculate the panel scale
private function changePanelScale():void {
	/* more information from
	   http://flexdevtips.blogspot.jp/2010/08/detecting-browser-height.html
	*/
	
	if (!AUTO_RESIZE_APP) {
		return;
	}
	
	if (this.systemManager.stage.displayState == StageDisplayState.FULL_SCREEN_INTERACTIVE || is_full_screen) {
		return;
	}
	
	
	var browser_width:Number = ExternalInterface.call("eval", "window.innerWidth");
	var browser_height:Number = ExternalInterface.call("eval", "window.innerHeight");
	//var browserHeight:Number = ExternalInterface.call("eval", "document.documentElement.clientHeight");
	//var browserHeight:Number = ExternalInterface.call("eval", "document.getElementsByTagName('body')[0].clientHeight");
	
	//myDebug(global_app_width + "," + global_app_height + " -- " + browser_width + "," + browser_height);
	var scaleX:Number = browser_width / global_app_width;
	var scaleY:Number = browser_height / global_app_height;
	//myDebug("scaleX = " + scaleX + ", scaleY = " + scaleY);
	
	// keep the ratio
	if (scaleX <= scaleY) {
		meetingPanel.scaleX = scaleX;
		meetingPanel.scaleY = scaleX;
	}
	else {
		meetingPanel.scaleX = scaleY;
		meetingPanel.scaleY = scaleY;
	}
}

// fit the video size to the object
private function reloadVideo():void {
	for (var i:int = 0; i < MAX_DISPLAYS; i++) {
		if (displayObj[i].connected) {
			myDebug("reloadVideo - vid:" + i);
			
			// calculate a video display size
			var vidWidth:int = displayObj[i].window.width - 2; // - displayObj[i].window.getStyle("borderThicknessRight") - displayObj[i].window.getStyle("paddingLeft") - displayObj[i].window.getStyle("paddingRight");
			var vidHeight:int = displayObj[i].window.height - displayObj[i].window.titleDisplay.height - 2; // - displayObj[i].window.getStyle("headerHeight");// - displayObj[i].window.getStyle("borderThicknessTop") - displayObj[i].window.getStyle("borderThicknessBottom") - displayObj[i].window.getStyle("paddingTop") - displayObj[i].window.getStyle("paddingBottom");
			// get an existing video object
			// the video object should be the latest children from function "doDisplayVideo"
			var vid1:Video = displayObj[i].vid.getChildAt(displayObj[i].vid.numChildren - 1);  // video object
			// change object's size
			vid1.width = vidWidth;
			vid1.height = vidHeight;
		}
	}
}

// calculate for small video layout
private function changeToSmallVideo():void {
	myDebug("changeToSmallVideo");
	
	// layout
	//controlArea.layout = Layout;
	//detailArea.layout = Layout1;
	meetingPanel.validateNow();
	meetingArea.validateNow();
	
	// size
	videoSection.width = meetingArea.width - 2; // gap
	// calculate video window size
	var v_w:int = videoSection.width /2 ; // 2 columns
	var v_h:int = v_w * (3 / 4);// ratio is 4:3
	v_h += 20; // reserve for header bar
	
	logoBG.width = videoSection.width;
	logoBG.height = v_h * 2;  // 2 rows
	videoSection.height = logoBG.height + controlArea.height + 4; // gap
	displayArea.width = logoBG.width;
	displayArea.height = logoBG.height;
	controlArea.width = logoBG.width;
	
	// position
	logoBG.x = 2; // gap
	logoBG.y = 2;
	controlArea.x = logoBG.x;
	controlArea.y = logoBG.height + 2; // gap
	
	// videos
	displayObj[0].window.doubleClickEnabled = true; // reset
	displayObj[0].window.width = v_w;
	displayObj[0].window.height = v_h;
	displayObj[0].window.x = 0;
	displayObj[0].window.y = 0;
	displayObj[1].window.width = v_w;
	displayObj[1].window.height = v_h;
	displayObj[1].window.x = displayArea.width / 2;
	displayObj[1].window.y = 0;
	displayObj[2].window.width = v_w;
	displayObj[2].window.height = v_h;
	displayObj[2].window.x = 0;
	displayObj[2].window.y = displayArea.height / 2;
	displayObj[3].window.width = v_w;
	displayObj[3].window.height = v_h;
	displayObj[3].window.x = displayArea.width / 2;
	displayObj[3].window.y = displayArea.height / 2;
	
	reloadVideo();
	// keeping the enlarge video even the main video setting
	/* use timout instead of directry call to fix bug */
	if (is_logging_in) {
		tmpTimeOutID = setTimeout(checkMainvideo, 100);
	}
	// focus the whitebaord area to activate the key event
	meetingPanel.focusManager.setFocus(whiteboardArea.wb_viewport);
}

// calculate for wide video layout
private function changeToWideVideo():void {
	myDebug("changeToWideVideo");
	
	meetingArea.validateNow();
	meetingPanel.validateNow();
	
	videoSection.width = meetingArea.width; 
	videoSection.height = meetingArea.height - userArea.height - devicesQuality.height - 230;  // video height
	
	//detailArea.visible = false;
	detailArea.width = meetingArea.width;
	detailArea.height = 184;
		
	myDebug("meetingArea : " + meetingArea.width + "," + meetingArea.height);
	
	//videoSection.height = meetingArea.height - userArea.height - devicesQuality.height - detailArea.height;  // video height
	logoBG.width = videoSection.width;
	logoBG.height = videoSection.height;
	displayArea.width = logoBG.width;
	displayArea.height = logoBG.height;
	myDebug("videoSection : " +  videoSection.width + "," + videoSection.height);
	myDebug("displayArea : " +  displayArea.width + "," + displayArea.height);
	
	// calculate video window size
	var v_h:int = videoSection.height / 3; // 3 rows
	var v_w:int = (v_h - 20) * (4 / 3);// ratio is 4:3 (20 -> header height)
	var mv_w:int = displayArea.width - v_w - 2;
	var mv_h:int = displayArea.height;//mv_w * (3 / 4);// ratio is 4:3 
	
	// main video
	displayObj[0].window.doubleClickEnabled = false; // set to big window
	displayObj[0].window.width = mv_w;
	displayObj[0].window.height = mv_h;
	displayObj[0].window.x = 0;
	displayObj[0].window.y = 0;
	// other videos
	displayObj[1].window.width = v_w;
	displayObj[1].window.height = v_h;
	displayObj[1].window.x = mv_w;
	displayObj[1].window.y = 0;
	displayObj[2].window.width = v_w;
	displayObj[2].window.height = v_h;
	displayObj[2].window.x = mv_w;
	displayObj[2].window.y = v_h;
	displayObj[3].window.width = v_w;
	displayObj[3].window.height = v_h;
	displayObj[3].window.x = mv_w;
	displayObj[3].window.y = v_h * 2;
	
	reloadVideo();
}

// calculate for wide video layout
private function changeToFullScreenVideo():void {
	myDebug("changeToFullScreenVideo");
	// layout
//	controlArea.layout = hLayout;
	
	meetingPanel.scaleX = 1;
	meetingPanel.scaleY = 1;
	
	// size
	videoSection.width = meetingArea.width - 2; // gap
	videoSection.height = meetingArea.height - 2; // gap
	logoBG.width = videoSection.width;
	logoBG.height = videoSection.height;
	displayArea.width = logoBG.width;
	displayArea.height = logoBG.height;
	
	// calculate video window size
//	var v_h:int = videoSection.height / 3; // 3 rows
//	var v_w:int = (v_h - 20) * (4 / 3);// ratio is 4:3 (20 -> header height)
//	var mv_w:int = displayArea.width - v_w - 2;
//	var mv_h:int = mv_w * (3 / 4);// ratio is 4:3 
//	mv_h += 20; // header
	
	// calculate video window size
	var v_h:int = videoSection.height / 3; // 3 rows
	var v_w:int = (v_h - 20) * (4 / 3);// ratio is 4:3 (20 -> header height)
	var mv_w:int = displayArea.width - v_w - 2;
	var mv_h:int = displayArea.height;//mv_w * (3 / 4);// ratio is 4:3 
	
//	if ((mv_h + controlArea.height) > videoSection.height) {
//		mv_h = videoSection.height - controlArea.height - 2;
//		mv_w = (mv_h - 20) * (4 / 3);// ratio is 4:3 (20 -> header height)
//	}
	
//	controlArea.width = mv_w;
	
	// position
	logoBG.x = 2; // gap
	logoBG.y = 2;
	controlArea.x = logoBG.x;
	controlArea.y = mv_h + 2; // gap
	
	// main videos
	displayObj[0].window.doubleClickEnabled = false; // set to big window
	displayObj[0].window.width = mv_w;
	displayObj[0].window.height = mv_h;
	displayObj[0].window.x = 0;
	displayObj[0].window.y = 0;
	// other videos
	displayObj[1].window.width = v_w;
	displayObj[1].window.height = v_h;
	displayObj[1].window.x = mv_w;
	displayObj[1].window.y = 0;
	displayObj[2].window.width = v_w;
	displayObj[2].window.height = v_h;
	displayObj[2].window.x = mv_w;
	displayObj[2].window.y = v_h;
	displayObj[3].window.width = v_w;
	displayObj[3].window.height = v_h;
	displayObj[3].window.x = mv_w;
	displayObj[3].window.y = v_h * 2;
	
	reloadVideo();
}

// calculate for full screen presentation
private function changeToFullScreenPresentation():void {
	myDebug("changeToFullScreenPresentation");
	
	meetingPanel.scaleX = 1;
	meetingPanel.scaleY = 1;
	
	// layout
	whiteboardArea.contentInfoFullscreen.includeInLayout = true;
	whiteboardArea.contentInfoFullscreen.visible = true;
	whiteboardArea.slide_list_box.visible = false;
	whiteboardArea.slide_list_box.width = 0;
	whiteboardArea.page_tool2.visible = whiteboardArea.slide_list_box.visible;
	whiteboardArea.page_tool2.width = 0;
	whiteboardArea.hidelist_btn.visible = whiteboardArea.slide_list_box.visible;
	
	whiteboardArea.contentTitle.text = roomTitle;
	
	// for slide video
	/*	if(slidevideo){
	slidevideo.pause();
	myDebug("slide video paused");
	validateWbLayout();
	slidevideo.resume();
	myDebug("slide video resumed");
	}
	*/	// update layout (double calls for correctly update)
	validateWbLayout();
	validateWbLayout();
	updateData(cursorBoolean);
	
	// focus the whitebaord area to activate the key event
	meetingPanel.focusManager.setFocus(whiteboardArea.wb_viewport);
}

private function enlargeDisplay(index:int, force_restore:Boolean = false):void {
	if (current_ui_mode == 1 || current_ui_mode == 2) {
		enlargeDisplaySmall(index, force_restore);
	}
	else if (current_ui_mode == 4) {
		enlargeDisplayWide(index, force_restore);
	}
}

// small video
private function enlargeDisplaySmall(index:int, force_restore:Boolean = false):void {
	myDebug("enlargeDisplaySmall - index:" + index);
	var i:int;
	if (displayObj[index].connected) {
		if (displayObj[index].enlarge || force_restore) {
			myDebug("enlargeDisplay - restore");
			main_video_index = -1; 
			
			// restore to original size and position
			displayObj[index].window.width = displayObj[index].old_w;
			displayObj[index].window.height = displayObj[index].old_h;
			displayObj[index].window.x = displayObj[index].old_x;
			displayObj[index].window.y = displayObj[index].old_y;
			displayObj[index].vid.scaleX = 1;
			displayObj[index].vid.scaleY = 1;
			displayObj[index].enlarge = false;
			
			for (i = 0; i < MAX_DISPLAYS; i++) {
				displayObj[i].window.visible = true;
			}
		}
		else {			
			myDebug("enlargeDisplay - index:" + index);
			main_video_index = index; 
			
			displayObj[index].old_w = displayObj[index].window.width;
			displayObj[index].old_h = displayObj[index].window.height;
			displayObj[index].old_x = displayObj[index].window.x;
			displayObj[index].old_y = displayObj[index].window.y;
			
			displayObj[index].window.width = displayArea.width;
			displayObj[index].window.height = displayArea.height;
			displayObj[index].window.x = 0;
			displayObj[index].window.y = 0;
			displayObj[index].vid.scaleX = (displayObj[index].window.width+2) / displayObj[index].old_w;
			displayObj[index].vid.scaleY = (displayObj[index].window.width+2) / displayObj[index].old_w;
			displayObj[index].enlarge = true;
			
			for (i = 0; i < MAX_DISPLAYS; i++) {
				if (i != index) {
					displayObj[i].window.visible = false;
				}
			}
		}
		
		//20130108 - set main video
		if (is_admin && is_shared_display) {    
			so_meeting.send("updateEnlargeSharedVideoDisplay", index, force_restore, clientID);	
			myDebug("SO.send : updateEnlargeSharedVideoDisplay");
		}
	}

}

// wide video
private function enlargeDisplayWide(index:int, force_restore:Boolean = false):void {
	myDebug("enlargeDisplayWide - index:" + index);
	var i:int;
	if (displayObj[index].connected && !force_restore) {
		// swap
		if (displayObj[MAINVIDEO_DISPLAY_INDEX].connected) {
			var cIdx1:int = displayObj[MAINVIDEO_DISPLAY_INDEX].connection;
			var cIdx2:int = displayObj[index].connection;
			
			myDebug("enlargeDisplay - swap:" + cIdx1 + ":" + cIdx2 + ":" + connectionObj[cIdx1].client + ":" + connectionObj[cIdx2].client );
			
			// clear video display
			// must to close video BIG_DISPLAY at first
			closeVideo(MAINVIDEO_DISPLAY_INDEX);
			closeVideo(index);
			
			// connect to video BIG_DISPLAY
			// local connection
			if (cIdx2 == CONN_INDEX_SENDER) {
				displayVideo(cIdx2, connectionObj[cIdx2].client, getClientName(connectionObj[cIdx2].client), true, myCam, null, MAINVIDEO_DISPLAY_INDEX);
			}
				// broadcast concection
			else {
				displayVideo(cIdx2, connectionObj[cIdx2].client, getClientName(connectionObj[cIdx2].client), false, null, connectionObj[cIdx2].ns, MAINVIDEO_DISPLAY_INDEX);
			}
			
			// connect to video N
			// local connection
			if (cIdx1 == CONN_INDEX_SENDER) {
				displayVideo(cIdx1, connectionObj[cIdx1].client, getClientName(connectionObj[cIdx1].client), true, myCam, null, index);
			}
				// broadcast concection
			else {
				displayVideo(cIdx1, connectionObj[cIdx1].client, getClientName(connectionObj[cIdx1].client), false, null, connectionObj[cIdx1].ns, index);
			}
			
		}
			// move to video BIG_DISPLAY
		else {
			myDebug("enlargeDisplay - move");
			
			var cIdx:int = displayObj[index].connection;
			
			// clear source video display
			closeVideo(index);
			// local connection
			if (cIdx == CONN_INDEX_SENDER) {
				displayVideo(cIdx, connectionObj[cIdx].client, getClientName(connectionObj[cIdx].client), true, myCam, null, MAINVIDEO_DISPLAY_INDEX);
			}
				// broadcast concection
			else {
				displayVideo(cIdx, connectionObj[cIdx].client, getClientName(connectionObj[cIdx].client), false, null, connectionObj[cIdx].ns, MAINVIDEO_DISPLAY_INDEX);
			}
		}
		
		updateUserDetails();
	}
}

public function updateMainvideoView(is_mainvideo:Boolean):void {
	myDebug("SO : updateMainvideoView");
	// clear timeout of layout changing
	clearInterval(tmpTimeOutID);
	tmpTimeOutID = 0;
	//
	if (current_ui_mode == 1 || current_ui_mode == 2) {
		updateMainvideoViewSamll(is_mainvideo);
	}
	else if (current_ui_mode == 4) {
		updateMainvideoViewWide(is_mainvideo);
	}
}

// small video
private function updateMainvideoViewSamll(is_mainvideo:Boolean):void {
	myDebug("updateMainvideoViewSamll - is_mainvideo : " + is_mainvideo );
	/*
	steps to make a presentation view
	1. backup data (for normal view)
	2. get the mainvideo id (for presentation view)
	3. get the connection of mainvideo
	4. get an existing video of mainvideo (if have)
	5. force close the current display of a mainvideo
	6. display a mainvideo video in the main display
	7. disable the close window and toggle window
	8. swap display (if have an existing video)
	9. enlarge the mainvideo's video display
	*/
	
	var i:int;
	var mainvideo_connection:int = -1;
	var mainvideo_id:int = -1;
	var old_mainvideo_vid:int = -1;
	var old_client_id:int = -1;
	var old_client_connection:int = -1;
	
	// step 1
	// backup the current connection
	if (displayObj[MAINVIDEO_DISPLAY_INDEX].connected) {
		old_client_connection = displayObj[MAINVIDEO_DISPLAY_INDEX].connection;
		old_client_id = connectionObj[old_client_connection].client;
	}
	
	// step 2
	// set mainvideo id
	if (is_mainvideo) {
		mainvideo_id = getMainvideoID();
	}
	else {
		mainvideo_id = old_client_id;
	}
	
	if (isClientCamOn(mainvideo_id)) {				
		// step 3
		// get mainvideo connection
		i = getClientConnection(mainvideo_id);
		if (i != -1) {
			mainvideo_connection = i;
		}
		
		// step 4
		// get an existing mainvideo video
		for (i = 0; i < MAX_DISPLAYS; i++) {
			if (displayObj[i].connected && connectionObj[displayObj[i].connection].client == mainvideo_id) {
				old_mainvideo_vid = i;
				break;
			}
		}
		
		// step 5
		// force to close new mainvideo video
		closeVideo(MAINVIDEO_DISPLAY_INDEX);
		closeVideo(old_mainvideo_vid);
		
		// step 6
		// display the mainvideo video in to new mainvideo video
		//if (mainvideo_id > 0) {
		// local connection
		if (mainvideo_connection == CONN_INDEX_SENDER) {
			displayVideo(mainvideo_connection, mainvideo_id, getClientName(mainvideo_id), true, myCam, null, MAINVIDEO_DISPLAY_INDEX);
		}
			// broadcast concection
		else {
			displayVideo(mainvideo_connection, mainvideo_id, getClientName(mainvideo_id), false, null, connectionObj[mainvideo_connection].ns, MAINVIDEO_DISPLAY_INDEX);
		}
		//}
		
		// step 7
		// set window actions
		if (is_mainvideo) {
			for (i = 0; i < MAX_DISPLAYS; i++) {
				displayObj[i].window.doubleClickEnabled = false;
			}
		}
		else {
			for (i = 0; i < MAX_DISPLAYS; i++) {
				displayObj[i].window.doubleClickEnabled = true;
			}
		}
		
		// step 8
		// toggle old display
		if (old_client_connection > -1 && old_client_id != mainvideo_id) {
			// connect to old_mainvideo_vid
			// local connection
			if (old_client_connection == CONN_INDEX_SENDER) {
				displayVideo(old_client_connection, connectionObj[old_client_connection].client, getClientName(connectionObj[old_client_connection].client) + "(" + resourceManager.getString('meeting_messages', 'label_host') + ")", true, myCam, null, old_mainvideo_vid);
			}
				// broadcast concection
			else {
				displayVideo(old_client_connection, connectionObj[old_client_connection].client, getClientName(connectionObj[old_client_connection].client), false, null, connectionObj[old_client_connection].ns, old_mainvideo_vid);
			}
		}
		
		// setp 9 
		// enlarge video display
		if (is_mainvideo) {
			enlargeDisplay(MAINVIDEO_DISPLAY_INDEX);
		}
	}
}

// wide video
private function updateMainvideoViewWide(is_mainvideo:Boolean):void {
	myDebug("updateMainvideoViewWide - is_mainvideo : " + is_mainvideo );
	/*
	steps to make a presentation view
	1. backup data (for normal view)
	2. get the mainvideo id (for presentation view)
	3. get the connection of mainvideo
	4. get an existing video of mainvideo (if have)
	5. force close the current display of a mainvideo
	6. display a mainvideo video in the main display
	7. swap display (if have an existing video)
	8. disable the close window and toggle window
	*/
	
	var i:int;
	var mainvideo_connection:int = -1;
	var mainvideo_id:int = -1;
	var old_mainvideo_vid:int = -1;
	var old_client_id:int = -1;
	var old_client_connection:int = -1;
	
	// step 1
	// backup the current connection
	if (displayObj[MAINVIDEO_DISPLAY_INDEX].connected) {
		old_client_connection = displayObj[MAINVIDEO_DISPLAY_INDEX].connection;
		old_client_id = connectionObj[old_client_connection].client;
	}
	
	// step 2
	// set mainvideo id
	if (is_mainvideo) {
		mainvideo_id = getMainvideoID();
	}
	
	if (isClientCamOn(mainvideo_id)) {				
		// step 3
		// get mainvideo connection
		for (i = 0; i < MAX_CONNECTIONS; i++) {
			if (connectionObj[i].connected && connectionObj[i].client == mainvideo_id) {
				mainvideo_connection = i;
				break;
			}
		}
		
		// step 4
		// get an existing mainvideo video
		for (i = 0; i < MAX_DISPLAYS; i++) {
			if (displayObj[i].connected && connectionObj[displayObj[i].connection].client == mainvideo_id) {
				old_mainvideo_vid = i;
				break;
			}
		}
		
		// step 5
		// force to close new mainvideo video
		closeVideo(MAINVIDEO_DISPLAY_INDEX);
		if (old_mainvideo_vid > -1) {
			closeVideo(old_mainvideo_vid);
		}
		
		// step 6
		// display the mainvideo video in to new mainvideo video
		// local connection
		if (mainvideo_connection == CONN_INDEX_SENDER) {
			displayVideo(mainvideo_connection, mainvideo_id, getClientName(mainvideo_id), true, myCam, null, MAINVIDEO_DISPLAY_INDEX);
		}
			// broadcast concection
		else {
			displayVideo(mainvideo_connection, mainvideo_id, getClientName(mainvideo_id), false, null, connectionObj[mainvideo_connection].ns, MAINVIDEO_DISPLAY_INDEX);
		}
		
		// step 7
		// toggle old display
		if (old_client_connection > -1 && old_client_id != mainvideo_id && old_mainvideo_vid > -1) {
			// connect to old_mainvideo_vid
			// local connection
			if (old_client_connection == CONN_INDEX_SENDER) {
				displayVideo(old_client_connection, connectionObj[old_client_connection].client, getClientName(connectionObj[old_client_connection].client) + "(" + resourceManager.getString('meeting_messages', 'label_host') + ")", true, myCam, null, old_mainvideo_vid);
			}
				// broadcast concection
			else {
				displayVideo(old_client_connection, connectionObj[old_client_connection].client, getClientName(connectionObj[old_client_connection].client), false, null, connectionObj[old_client_connection].ns, old_mainvideo_vid);
			}
		}
		
		// step 8
		// set window actions
		if (is_mainvideo) {
			for (i = 0; i < MAX_DISPLAYS; i++) {
				displayObj[i].window.doubleClickEnabled = false;
			}
		}
	}
	
	// return to normal mode
	if (!is_mainvideo) {
		for (i = 0; i < MAX_DISPLAYS; i++) {
			if (i == MAINVIDEO_DISPLAY_INDEX) {
				displayObj[MAINVIDEO_DISPLAY_INDEX].window.doubleClickEnabled = false;
			}
			else {
				displayObj[i].window.doubleClickEnabled = true;
			}
		}
	}
}

// manage the slide list and navigation control for the whiteboard mode
private function toggleSlideTitle(evt:Event = null): void {
	if (current_ui_mode == UI_MODE_WHITEBOARD) {
		if (is_presenter || is_offline_mode) {
			if (whiteboardArea.slide_list_box.visible == false) {
				whiteboardArea.slide_list_box.visible = true;
				whiteboardArea.slide_list_box.width = 146;
				whiteboardArea.page_tool2.visible = !whiteboardArea.slide_list_box.visible;
				whiteboardArea.page_tool2.width = 0;
			}
			else {
				whiteboardArea.slide_list_box.visible = false;
				whiteboardArea.slide_list_box.width = 0;
				whiteboardArea.page_tool2.visible = !whiteboardArea.slide_list_box.visible;
				whiteboardArea.page_tool2.width = 32;
			}
			whiteboardArea.hidelist_btn.visible = true;
			meetingArea.validateNow();
		}
		else {
			whiteboardArea.slide_list_box.visible = false;
			whiteboardArea.slide_list_box.width = 0;
			whiteboardArea.page_tool2.visible = whiteboardArea.slide_list_box.visible;
			whiteboardArea.page_tool2.width = 0;
			whiteboardArea.hidelist_btn.visible = whiteboardArea.slide_list_box.visible;
		}
		
		// update layout (double calls for correctly update)
		validateWbLayout();
		validateWbLayout();
		updateData(cursorBoolean);
	}
}

// update the layout
private function validateWbLayout(): void {
	myDebug("validateWbLayout");
	
	meetingArea.validateNow();
	wbArea.validateNow();
	
	if (is_video_mode && is_presenter) {
		whiteboardArea.video.visible = true;
		whiteboardArea.video_control.visible = whiteboardArea.video.visible;
		whiteboardArea.video_control.height = 36;
	}
	else {
		whiteboardArea.video.visible = true;
		whiteboardArea.video_control.visible = false;
		whiteboardArea.video_control.height = 0;
	}
	
	whiteboardArea.wb_container.width = whiteboardArea.wb_content_group.width;
	whiteboardArea.wb_container.height = (is_video_mode) ? (whiteboardArea.wb_content_group.height - whiteboardArea.video_control.height) : (whiteboardArea.wb_content_group.height);
	whiteboardArea.video.width = whiteboardArea.wb_container.width; 
	whiteboardArea.video.height = whiteboardArea.wb_container.height;
	whiteboardArea.slideimg.width = whiteboardArea.video.width;
	whiteboardArea.slideimg.height = whiteboardArea.video.height - 4; //4 for bottom padding
	whiteboardArea.svg.width = whiteboardArea.video.width;
	whiteboardArea.svg.height = whiteboardArea.video.height;
	whiteboardArea.wb_area.width = whiteboardArea.video.width;
	whiteboardArea.wb_area.height = whiteboardArea.video.height;
	if (svideo) {
		//svideo.width = whiteboardArea.video.width;
		//svideo.height = whiteboardArea.video.height;
		svideo.height = wb_box.video.height - 4; // 4  for bottom padding
		svideo.width = svideo.height * (video_width/video_height);
		svideo.x = ( wb_box.video.width - svideo.width ) / 2;
	}
	// for SVG format
	svgParseCompleteHandler();
}
