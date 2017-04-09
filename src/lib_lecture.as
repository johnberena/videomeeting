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

include "lib_header.as";
include "lib_communication.as";

import com.lorentz.SVG.display.SVGDocument;
import com.lorentz.SVG.events.SVGEvent;

import flash.net.NetStream;
import flash.net.URLLoader;
import flash.net.URLRequest;

import mx.events.CloseEvent;
import mx.events.ResizeEvent;
import mx.managers.PopUpManager;

import spark.components.VideoDisplay;

private var loging_name:String;
private var loging_number:Number;
private var loging_count:Number;

private var is_logging_in:Boolean = false;
private var is_first_connect:Boolean = true;
private var is_close_connection:Boolean = false;
private var is_admin_kick:Boolean = false; //If true, system cannot be login-ed

private var room:String; // virtual room
private var room_changed:Boolean; // room change status
private var content_type:String; //Type of media (image, vector, video)
private var content:String; // Link of content
private var content_predict:String; // Link of predicted content
private var stream_id:int; // stream id
private var stream_status:Boolean; // stream status
private var old_room:String; // virtual room (old)
private var old_room_changed:Boolean; // room change status (old)
private var old_content:String; // Link of content (old)
private var old_stream_id:int; // stream id (old)
private var old_stream_status:Boolean; // stream status (old)
private var old_anno_mode:int; // annotation mode (old)
private var last_anno_timestamp:Number; // timestamp for updating annotation
private var video_width:Number; //emdedded video
private var video_height:Number; //emdedded video
private var video_ns:NetStream = null;
private var video_st:SoundTransform = new SoundTransform();
private var video_data:Video = null;
private var lectureVideoFloat:lecture_video = null;

private static var MAX_CONNECTIONS:int = 2;
private var connectionObj:Array = new Array();
private static var CONN_INDEX_SENDER:int = 0;	// fix sender index
private static var CONN_INDEX_RECEIVER:int = 1;	// fix reveiver index

private var old_page_num:Number = 1; //Slide Page Number (old)
private var present_page_num:Number = 1; //Slide Page Number (Present)
private var last_page_num:Number = 1; //Slide Page Number (Last)


[Bindable]
private var image_files:ArrayCollection;

private function loginManagement():void {
	// protect serveral clicks from user
	btnLogin.enabled = false;
	
	if (!is_logging_in) {
		// for auto reconnection
		reconnectTimeID = 0;
		reconnectCount = 0;
		is_auto_reconnection = false;
		
		meetingLogin();
	}
	else {
		is_auto_reconnection = false;
		meetingLogout();
	}
}

private function meetingLogin():void {
	// initial system
	resetEnvironment();
	
	is_close_connection = false;
	
	NetConnection.defaultObjectEncoding = flash.net.ObjectEncoding.AMF0;
	SharedObject.defaultObjectEncoding  = flash.net.ObjectEncoding.AMF0;
	
	if(txtUser.text != "" && !is_admin_kick) {
		nc = new FMSConnection();
		nc.addEventListener("success", connectionSuccessHandler);
		nc.addEventListener("failed", connectionFailed);
		nc.addEventListener("closed", connectionClosed);
		
		// verify user name
		var identifier:String = txtUser.text;
		while(identifier.search(" ") > 0) {
			identifier = identifier.replace(" ", "_");
		}
		
		// 1st try
		connectRTMP();
		// 2nd try
		rtmpTimeOutID = setTimeout(connectRTMPT, 5000);
	} else {
		Alert.show(resourceManager.getString('meeting_messages', 'alert_invalid_name'), resourceManager.getString('meeting_messages', 'alert_system'));
	}
	btnLogin.enabled = true;
}

private function meetingLogout():void {
	// clear video display
	slidesvg.source = null;
	slideimg.source = null;
	slidevid.source = null;
	cursorimg.visible = false;
	
	thumbnail_list.dataProvider = null;
	lectureVideo.removeChildren();
	
	lectureVideoContainer.enabled = false;
	chatArea.enabled = false;
	contentArea.enabled = false;
	thumbnail_list.enabled = false;
		
	btnLogin.enabled = true;
	btnLogin.label = resourceManager.getString('meeting_messages', 'login');
	
	present_page.text = "0";
	last_page.text = "0";
	infoText.text = "";
//	btnFullscreen.visible = false;
	//presenterVideo.removeChildren();
	//PopUpManager.removePopUp(lectureVideoFloat);

	//	lectureVideoFloat.closeWindow();
//	lectureVideoFloat = null;
	//drawgroup.removeAllElements();
	//cursorimg.visible = false;
	

	
	txtUser.enabled = true;
	rtmpTimeOutID = 0;
	is_admin_kick = false; //false means system can be login-ed
	is_first_connect = true;
	is_logging_in = false;
	// deley for closing connection
	is_close_connection = true;
	
	closeNetworkConnection();
	
	globalTimer.stop();
	globalTimer = null;
} 

// for handling the auto-reconnection
private function reConnection():void {
	meetingLogin();
}

private function cleanUp():void {
	if(is_logging_in){
		is_auto_reconnection = false;
		meetingLogout();
	}
}

private function resetEnvironment():void {
	// initial connectionObj variables
	// 0 - sender
	// 1 - receiver
	connectionObj = new Array();
	for (var i:int = 0; i < MAX_CONNECTIONS; i++) {
		var cobj:Object = new Object();
		cobj.ns = null; // NetStream connectionObj
		if (SEPARATE_VIDEO_STREAM) {
			cobj.ns2 = null;
		}
		cobj.client = -1;	// client id
		cobj.connected = false;	// connected status
		
		connectionObj.push(cobj);
	}
	
	room = "";
	room_changed = false;
	old_room = "";
	old_room_changed = false;
	content = "";
	old_content = "";
	stream_id = -1;
	old_stream_id = -1;
	stream_status = false;
	old_stream_status = false;
	old_anno_mode = 0;
	last_anno_timestamp = 0;
	drawgroup.removeAllElements();
	cursorimg.visible = false;
//	btnLecturerVideo.visible = false;
	rtmpTimeOutID = 0;
	txtUser.enabled = true;
	is_admin_kick = false; //false means system can be login-ed
	is_first_connect = true;
	is_logging_in = false;	
	
	lectureVideoContainer.enabled = false;
	chatArea.enabled = false;
	contentArea.enabled = false;
	thumbnail_list.enabled = false;
}

private function connectionSuccessHandler(event:Event):void {
	myDebug("connected to server using .. " + connected_protocol);
	clearTimeout(rtmpTimeOutID);
	rtmpTimeOutID = 0;
	
	if (reconnectTimeID != 0) {  //Remove setInterval
		myDebug("clear reconnection timer");
		clearInterval(reconnectTimeID);
		reconnectTimeID = 0;
		reconnectCount = 0;
	}
	
	lectureVideoContainer.enabled = true;
	chatArea.enabled = true;
	contentArea.enabled = true;
	thumbnail_list.enabled = true;
	
	// set login flag
	is_logging_in = true;
	btnLogin.enabled = true;
	btnLogin.label = resourceManager.getString('meeting_messages', 'logout');
//	btnFullscreen.visible = true;
	
	loging_name = txtUser.text;
	
	txtUser.enabled = false;
	// Get Server Client ID
	clientID = nc.clientID;
	
	// start a global timer 
	globalTimeCounter = 0;
	globalTimer = new Timer(1000); // 1 second
	globalTimer.addEventListener(TimerEvent.TIMER, taskSchedule); 
	globalTimer.start();
	
	// waiting for establish
	wait(500);
	
	// create stream connection
	createNetStream();
	
	// create share object for chat and other function with minimal use
	createShareObject();
	
	nc.call('init_params', null, contentID); // initial data on server 
	myDebug("NC.call : init_params");
	nc.call("getContentID", new Responder(loadContentData));
	myDebug("NC.call : getContentID");
}

private function connectionFailed(event:Event):void {
	btnLogin.enabled = true;
	btnLogin.label = resourceManager.getString('meeting_messages', 'logout');
}

private function connectionClosed(evtChange:Event):void {
	myDebug("connectionClosed");
	if(is_logging_in) {
		NotificatorManager.show(resourceManager.getString('meeting_messages', 'disconnect_warning'), NotificatorMode.WARNING, noticsDuration);
		is_auto_reconnection = true;
		meetingLogout();
		// call auto-reconnection
		reconnectTimeID = setInterval(autoReconnecting, 20000); // check again on next 20 seconds
		reconnectCount = 0;
	}
}

private function createNetStream():void {
	myDebug("createNetStream");
	var h264Settings:H264VideoStreamSettings = new H264VideoStreamSettings();  
	h264Settings.setProfileLevel(H264_PROFILE, H264_LEVEL);
	
	// establish a stream for sending 
	connectionObj[CONN_INDEX_RECEIVER].ns = new NetStream(nc);
	connectionObj[CONN_INDEX_RECEIVER].ns.bufferTime = SEND_BUFFER_TIME; //Set Buffer time, 0 means minimum delay
	
	// ***  ENABLE THIS SECTION IN CASE OF WE NEED TO BROADCAST STREAM TO SERVER ***
	/*
	connectionObj[CONN_INDEX_SENDER].ns = new NetStream(nc);
	connectionObj[CONN_INDEX_SENDER].ns.bufferTime = SEND_BUFFER_TIME; //Set Buffer time, 0 means minimum delay
	
	if (H264_VIDEO_CODEC) {
		connectionObj[CONN_INDEX_SENDER].ns.videoStreamSettings = h264Settings; // Set H264 Encoding
		connectionObj[CONN_INDEX_SENDER].ns.publish("B" + clientID.toString() + ".f4v", "live");
	} else {
		connectionObj[CONN_INDEX_SENDER].ns.publish("B" + clientID.toString(), "live");
	}
	
	if (SEPARATE_VIDEO_STREAM) {
		connectionObj[CONN_INDEX_SENDER].ns2 = new NetStream(nc);
		connectionObj[CONN_INDEX_SENDER].ns2.bufferTime = SEND_BUFFER_TIME; //Set Buffer time, 0 means minimum delay
		if (H264_VIDEO_CODEC) {
			connectionObj[CONN_INDEX_SENDER].ns2.videoStreamSettings = h264Settings; // Set H264 Encoding
			connectionObj[CONN_INDEX_SENDER].ns2.publish("V" + clientID.toString() + ".f4v", "live");
		} else {
			connectionObj[CONN_INDEX_SENDER].ns2.publish("V" + clientID.toString(), "live");
		}
	}
	*/
	// polling data from server
//	loadContentData(contentID);

}

private function createShareObject():void {
	myDebug("createShareObject");
	
	so_lecture = SharedObject.getRemote("lecture", nc.uri, true);
	so_lecture.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
	so_lecture.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
	so_lecture.addEventListener(SyncEvent.SYNC, sharedObjectSyncHandler);
	so_lecture.client = this;
	so_lecture.connect(nc);
	
}

private function sharedObjectSyncHandler(event:SyncEvent):void {
	//Logger.debug("sharedObjectSyncHandler:code: " + event.changeList);	
}

private function netStatusHandler(event:NetStatusEvent):void {
	//Logger.debug("netStatusHandler:code: " + event.info.code);
}

private function asyncErrorHandler(event:AsyncErrorEvent):void {
	//Logger.debug("asyncErrorHandler:code: " + event.error);
}

private function closeNetworkConnection():void {
	myDebug("closeNetworkConnection");
	// close all stream connections
	for (var i:int = 0; i < MAX_CONNECTIONS; i++) {
		if (connectionObj[i].ns) {
			connectionObj[i].ns.close();
		}
		connectionObj[i].ns = null;
		if (SEPARATE_VIDEO_STREAM) {
			if (connectionObj[i].ns2) {
				connectionObj[i].ns2.close();
			}
			connectionObj[i].ns2 = null;
		}
		connectionObj[i].connected = false;
	}
	// close connection
	nc.close();
	nc = null;
}

// dummy function
private function networkBWHandler(netBW:Number):void {

}

// check the latest content
public function loadContentData(cid:String):void {
	myDebug("loadContentData");
	if (cid != contentID && cid != null) {
		contentID = cid;
	}
	
	if (is_logging_in){  // protect for logout step
	//	myDebug("content file = " + contentID + "/current_state.xml");
		// fixed always read data from cache
		var loader:URLLoader = new URLLoader();
		var header:URLRequestHeader = new URLRequestHeader("pragma", "no-cache");
	//	var url:URLRequest = new URLRequest(contentID + "/current_state.xml");
		var url:URLRequest = new URLRequest(contentID + "/working/content_description.xml");
		url.requestHeaders.push(header);
		url.method = URLRequestMethod.GET;
		url.data = new URLVariables("time="+Number(new Date().getTime()));
		loader.addEventListener(Event.COMPLETE, retrieveContentData);
		loader.load(url);
	}
}

// get data from the metadata
private function retrieveContentData(event:Event):void {
	myDebug("retrieveContentData");
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
			image = contentID + "/working" + img_src;
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
	myDebug("total slides = " + image_files.length);
	
	present_page.text = present_page_num.toString();
	last_page.text = (image_files.length).toString();	// total number of slides
    //last_page.text = last_page_num.toString();

	getCurrentSlide();
}	

private function getCurrentSlide():void {
	myDebug("getCurrentSlide");
	nc.call("getRoomState", new Responder(setRoomState));
	myDebug("NC.call : getRoomState");
	
	// show images in the slide list
	thumbnail_list.dataProvider = image_files;
	thumbnail_list.validateNow();
	thumbnail_list.selectedIndex = present_page_num - 1; // set to the first slide
	thumbnail_list.scrollToIndex(thumbnail_list.selectedIndex);
	
}

// set the current room state from server
private function setRoomState(result:Array): void {
	myDebug("setRoomState");
	
	/*
	result[0] - currentPageNumber // First Slide
	result[1] - currentContentID // Currently used contentID or roomid
	result[2] - currentPresenterID // 0 - No Presenter; clientID - Presenter's Client ID number (one-Presenter policy)
	result[3] - presenterStreamStatus // 0 - No Video Stream; 1 - Video Stream
	result[4] - currentLectureMode // Presentation mode; default is cursor mode
	*/
	
	setSlideNumber(result[0]);
	updateVideoData(result[2], (result[3] == 1) ? true : false);
	//manageInformation(result[2], result[3]);
}

// set current slide number
public function setSlideNumber(new_page:int, old_page:int = 1, skip_sync_slide:Boolean = false):void {
	myDebug("SO.recv : setSlideNumber : new_page = " + new_page);
	
	present_page_num = new_page;
	present_page.text = present_page_num.toString();
	old_page_num = old_page;
		
	updateContentData();
}

/*
public function manageInformation(streamID:int, status:int):void {
	if (streamID!=0 && status==1){
		infoText.text = "Info: Lecture On-going";
	} else if (streamID!=0 && status==0) {
		infoText.text = "Info: Lecturer's video is unavailable.";
	} else if (streamID==0 && status==1) {
		infoText.text = "Info: No Lecturer at the moment.";
	} else if (streamID==0 && status==0) {
		infoText.text = "Info: No Lecturer at the moment.";
	}
}
*/

// set cursor position
public function syncCursor(cursor_x:Number, cursor_y:Number): void {
	myDebug("SO.recv : syncCursor");
		
	var new_cursor_x:Number = (cursor_x * drawgroup.width) / 100;
	var new_cursor_y:Number = (cursor_y * drawgroup.height) / 100;
	cursorimg.visible = true;
	cursorimg.x = new_cursor_x - 8;
	cursorimg.y = new_cursor_y - 8;
}

// update video data
public function updateVideoData(streamID:int, status:Boolean):void {
	myDebug("updateVideoData");
	myDebug("updateVideoData stream: " + streamID + " ; " + status );
	stream_id = streamID;
	stream_status = status;
	
	// play stream 
	if (stream_status) {
		if(H264_VIDEO_CODEC) {
			connectionObj[CONN_INDEX_RECEIVER].ns.play("B" + stream_id + ".f4v", -1);
		} else {
			connectionObj[CONN_INDEX_RECEIVER].ns.play("B" + stream_id, -1);
		}
		if (SEPARATE_VIDEO_STREAM) {
			if(H264_VIDEO_CODEC){
				connectionObj[CONN_INDEX_RECEIVER].ns2.play("V" + stream_id + ".f4v", -1);
			} else {
				connectionObj[CONN_INDEX_RECEIVER].ns2.play("V" + stream_id, -1);
			}
		}
		
		fixedLectureVideo();
	//	btnLecturerVideo.visible = true;
	}
	else {
		if (lectureVideoFloat != null) {   // clear floating video
			lectureVideoFloat.closeWindow();
			lectureVideoFloat = null;
			myDebug("remove lectureVideoFloat");
		}
	//	btnLecturerVideo.visible = false;
		
		if (lectureVideo != null) {   // clear fixed video
			lectureVideo.removeChildren(); 
			myDebug("remove lectureVideoFixed");
		}
	
	}
	
	if (streamID!=0 && status){
		infoText.text = "Info: Lecture On-going";
	} else if (streamID!=0 && !status) {
		infoText.text = "Info: Lecturer's video is unavailable.";
	} else if (streamID==0 && status) {
		infoText.text = "Info: No Lecturer at the moment.";
		cursorimg.visible = false;
	} else if (streamID==0 && !status) {
		infoText.text = "Info: No Lecturer at the moment.";
		cursorimg.visible = false;
	}
	
	connectionObj[CONN_INDEX_RECEIVER].connected = true;
}


//display floating lecturer video
private function floatLectureVideo():void {
	myDebug("display floatLectureVideo");
	if (lectureVideoFloat == null) {
		lectureVideoFloat = lecture_video(PopUpManager.createPopUp(this, lecture_video, false));
		if (SEPARATE_VIDEO_STREAM) {
			lectureVideoFloat.initData(connectionObj[CONN_INDEX_RECEIVER].ns2);
		}
		else {
			lectureVideoFloat.initData(connectionObj[CONN_INDEX_RECEIVER].ns);
		}
		lectureVideoFloat.addEventListener(CloseEvent.CLOSE, closeVideoWindow);
	}
}

private function closeVideoWindow(evt:CloseEvent):void {
	lectureVideoFloat = null;
}

//display fixed lecturer video
private function fixedLectureVideo():void {
	myDebug("display fixedPresenterVideo");
	
	var video = new Video(lectureVideoContainer.width, lectureVideoContainer.height);
	video.width = lectureVideoContainer.width;
	video.height = lectureVideoContainer.height;
	
	if (SEPARATE_VIDEO_STREAM) {
		video.attachNetStream(connectionObj[CONN_INDEX_RECEIVER].ns2);
	}
	else {
		video.attachNetStream(connectionObj[CONN_INDEX_RECEIVER].ns);
	}	
	
	lectureVideo.addChild(video);
}


// update presentation data
private function updateContentData():void {
	myDebug("updateContentData");
	cursorimg.visible = false;
	
	present_page.text = present_page_num.toString();
	
	thumbnail_list.selectedIndex = present_page_num - 1;
	thumbnail_list.scrollToIndex(thumbnail_list.selectedIndex);

	
	//retrieving file conversion output
	var image:String = thumbnail_list.selectedItem.image;
	var imageExt:String = image.substring(image.lastIndexOf(".")+1, image.length);
	
	//retrieving slide type
	var slide_type:String = thumbnail_list.selectedItem.type;
	myDebug("slide_type = " + slide_type);
	myDebug("slide_content = " + image);
	
	
	slidevid.removeChildren();
	if (video_ns) {
		video_ns.pause();
		video_ns = null;
	}
	
	if (slide_type.toLowerCase() == "vector") { //SVG
		myDebug("data content : SVG");
		slideimg.visible = false;
		slidesvg.visible = true;
		slidevid.visible = false;
		
		slidesvg.addEventListener(SVGEvent.PARSE_COMPLETE, svgParseCompleteHandler);
		slidesvg.addEventListener(SVGEvent.PARSE_COMPLETE, nextSlidePrediction1);
		slidesvg.width = viewportContainer.width - 2; // 2 = border
		slidesvg.height = viewportContainer.height - 2;
		
		slidesvg.scaleX = 0.45;
		slidesvg.scaleY = 0.45;
		slidesvg.source = content;
		slideimg.source = null;
	}
	else if (slide_type.toLowerCase() == "video") {
		myDebug("data content : Video");
		slidesvg.visible = false;
		slideimg.visible = false;
		slidevid.visible = true;
		
		var nsClient:Object = {};
		nsClient.onMetaData = ns_onMetaData;
		
		video_ns= new NetStream(nc);
		var video_data:Video = new Video();
		video_data.attachNetStream(video_ns);
		video_data.width = slidevid.width;
		video_data.height = slidevid.height;
		video_data.visible = true;
		slidevid.addChild(video_data);
		video_ns.play(content);
	//	video_data.x = ( viewportGroup.width - video_data.width ) / 2;
		
		slidesvg.source = null;
		slideimg.source = null;
	}
	else {
		myDebug("data content : Image");
		slidesvg.visible = false;
		slideimg.visible = true;
		slidevid.visible = false;
		
	//	slideimg.addEventListener(Event.COMPLETE, nextSlidePrediction);
		slideimg.source = thumbnail_list.selectedItem.image;
	//	slideimg.source = content;
		slidesvg.source = null;
	}
}

private function ns_onMetaData(item:Object):void {	
	myDebug("video_duration: " + item.duration);
	myDebug("video_width: " + item.width);
	myDebug("video_height: " + item.height);
	video_width = item.width;
	video_height = item.height;
	video_data.height = viewportGroup.height;
	video_data.width = video_data.height * (video_width/video_height);
	video_data.x = ( viewportGroup.width - video_data.width ) / 2;
}

private function svgParseCompleteHandler(e:SVGEvent = null):void {
	myDebug("svgParseCompleteHandler");
	// calculate a scale
	if (slidesvg.visible) {
		var svgDoc:SVGDocument = slidesvg.svgDocument;
		var scaleX:Number = (slidesvg.width - 10) / svgDoc.width;  // 10 = gap
		var scaleY:Number = (slidesvg.height - 10) / svgDoc.height;
		slidesvg.scaleX = (scaleX < scaleY) ? scaleX : scaleY;
		slidesvg.scaleY = slidesvg.scaleX;
	}
}

//sync video playback
public function doPlay (vtime:int):void {
	myDebug("Synchronize video play");
	video_ns.seek(vtime);
	video_ns.resume();	
}

//sync video pause
public function doPause (vtime:int):void {
	myDebug("Synchronize video pause ");
	video_ns.pause();
	video_ns.seek(vtime);
	video_ns.pause();
}

//sync video replay
public function doReplay():void {
	myDebug("Synchronize video replay ");
	video_ns.pause();
	video_ns.seek(0);
	video_ns.resume();
}

//sync speaker status
public function doSpeakerStatusChange (status:Boolean):void {
	myDebug("Synchronize speaker status  ");
	if(status) {
		video_st.volume = 1.0;
		video_ns.soundTransform = video_st;
		myDebug("Turn-on speaker");
	}
	else if (!status) {
		video_st.volume = 0;
		video_ns.soundTransform = video_st;
		myDebug("Turn-off speaker");
	}
}

// display cursor
private function updateCursor(): void {
	myDebug("updateCursor");
	// retrieve existing draw data
	nc.call('getCursorPosition', new Responder(showCursor));
	myDebug("NC.call : getCursorPosition");
}

private function showCursor(result:Array): void {
	myDebug("showCursor");
	if (Number(result[0]) == -1 && Number(result[1]) == -1) {
		cursorimg.visible = false;
	}
	else {
		// convert from percentage value to actual position
		var new_cursor_x:Number = (Number(result[0]) * viewportContainer.width) / 100;
		var new_cursor_y:Number = (Number(result[1]) * viewportContainer.height) / 100;
		cursorimg.visible = true;
		cursorimg.x = new_cursor_x - 8;
		cursorimg.y = new_cursor_y - 8;
	}
}

// display annotation
private function updateAnnotationData(): void {
	myDebug("updateAnnotationData");
	// retrieve existing draw data
	nc.call('getDrawData', new Responder(drawExistingData));
	myDebug("NC.call : getDrawData");
}

/** 
 * Draw Existing Annotation Data 
 **/

private function drawExistingData(result:Array): void {
	myDebug("drawExistingData");
	// clear all
	drawgroup.removeAllElements();
	
	if (result.length > 0) {
		// add layer
		var layer:Group = new Group(); 
		layer.width = drawgroup.width; 
		layer.height = drawgroup.height;
		layer.x = 0;
		layer.y = 0; 
		drawgroup.addElement(layer);
		
		var i:int = 0;
		var dataPackLen:int = 2;
		var is_set_attrib:Boolean = true;
		while (i < result.length) {
			// if found new line, add new layer
			if ((result[i] == -1) && (result[i+1] == -1)) {
				//myDebug("set attrib");
				// ignore the last end point of line
				if (i < (result.length - dataPackLen - 1)) {
					is_set_attrib = true;
				}
			}
			// draw data
			else {
				if (is_set_attrib) {
					//myDebug("set draw attributes");
					layer.graphics.lineStyle(result[i], result[i+1], 1);
					
					// move to next data set
					i += dataPackLen;
					// set the first point
					var point_x:Number = (Number(result[i]) * layer.width) / 100;
					var point_y:Number = (Number(result[i+1]) * layer.height) / 100;
					layer.graphics.moveTo(point_x, point_y); 
				}
				else {
					var point_x:Number = (Number(result[i]) * layer.width) / 100;
					var point_y:Number = (Number(result[i+1]) * layer.height) / 100;
					layer.graphics.lineTo(point_x, point_y);
				}
				is_set_attrib = false;
			}
			i += dataPackLen;
		}
	}
}

// Predict the next slide for background downloading
private function nextSlidePrediction1(event:SVGEvent):void {
	nextSlidePrediction(null);
}

// load image (to broser's cache)
private function nextSlidePrediction(event:Event):void {
	if (content_predict != null) {
		myDebug("nextSlidePrediction : content = " + content_predict);
		var predictLoader:URLLoader = new URLLoader();
		var predictRequest:URLRequest = new URLRequest(content_predict);
		predictLoader.addEventListener(Event.COMPLETE, onPredictionComplete);
		predictLoader.load(predictRequest);
	}
}

private function onPredictionComplete(event:Event):void {
	myDebug("predict image download has been completed");
}

// tasks schdules
private function taskSchedule(e:TimerEvent):void {
	// increase counter
	globalTimeCounter++;
	
	// update content every 2 seconds
	if ((globalTimeCounter % 2) == 0) {
       //loadContentData();   // changed to S.O.
	}
	
	// check the logout signal
	if (is_close_connection) {
		closeNetworkConnection();
	}
}