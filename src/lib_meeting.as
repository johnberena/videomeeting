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
include "lib_administrator.as";

[Bindable]
private var dpUsers:ArrayCollection;

//Microphone Activity Level
private var micDelay:uint	= 100;
private var micRepeat:uint	= 0; 
private var micTimer:Timer = new Timer(micDelay, micRepeat);
private var myShape:Shape = new Shape();
private var gradientBoxMatrix:Matrix = new Matrix();

//Sound Control and Meter 
private var nsst:SoundTransform = new SoundTransform();
private var speakerTimer:Timer = new Timer(100, 0);

private var myCam:Camera;
private var myMic:Microphone;			
private static var MAX_CONNECTIONS:int = 100;
private var connectionObj:Array = new Array();
private static var CONN_INDEX_SENDER:int = 0;	// fix sender index
private static var MAX_DISPLAYS:int = 4;
private var displayObj:Array = new Array();
private var meetingUsers:Array;
private var MAINVIDEO_DISPLAY_INDEX:int = 0;	// index for mainvideo display

// echo test window
private var echoTestBox:echotest_box = null;

// sip dialer box
private var sipDialerBox:inviteSIPUser = null;

// user management by admin
private var userManagementPanel:admin_panel = null;

// chat floating panel
private var chatFloatingPanel:chat_panel = null;

private var loging_name:String;
private var loging_number:Number;
private var loging_count:Number;

private var is_logging_in:Boolean = false;
private var is_cam_on:Boolean = false;
private var is_mic_on:Boolean = false;
private var is_echo_on:Boolean = false;
private var is_spkr_on:Boolean = false;
private var is_first_connect:Boolean = true;
private var is_close_connection:Boolean = false;

private var qualityMode:int = 0;
// stream quality for poor, low, medium, high setting; 
// {video width, video height, video frame rate, video quality, audio sample rate}
private var qualityArray:Array = [{w:0, h:0, f:0, q:0, s:0},
	{w:160, h:120, f:5, q:25, s:8},
	{w:160, h:120, f:5, q:50, s:8},
	{w:320, h:240, f:5, q:50, s:8},
	{w:640, h:480, f:5, q:80, s:8},
	{w:1024, h:768, f:15, q:80, s:8}];


private function networkBWHandler(netBW:Number):void {
	if (bwInfo.visible == true) {
		bwInfo.text = "BW : " + parseInt(netBW.toString()) + " Bit";
	}
	
	if (qualityList.selectedIndex == 0) {
		if (netBW < 100) {
			changeQuality(1);
		}
		else if (netBW >= 100 && netBW < 200) {
			changeQuality(2);
		}
		else if (netBW >= 200 && netBW < 300) {
			changeQuality(3);
		}
		else {
			changeQuality(4);
		}
	}
}

// for handling the auto-reconnection
private function reConnection():void {
	meetingLogin();
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
		if (is_presenter) {	
			is_presenter_reconnect = true;	
		}

		meetingLogout();
		// call auto-reconnection
		reconnectTimeID = setInterval(autoReconnecting, 20000); // check again on next 20 seconds
		reconnectCount = 0;
	}
}

public function closeConnection(clientid:int):void {
	var i:int = getClientConnection(clientid);
	if (i != 1) {
		myDebug("SO : closeConnection - conn:" + i + ", clientid:" + clientid);
		
		var uname:String = getClientName(connectionObj[i].client);
		if (uname != null) {
			NotificatorManager.show("'" + uname + "' " + resourceManager.getString('meeting_messages', 'is_disconnected'), NotificatorMode.WARNING, noticsDuration);
		}
		
		closeVideo(connectionObj[i].display);
		
		// clear connection
		connectionObj[i].ns.close();
		connectionObj[i].ns = null;
		if (SEPARATE_VIDEO_STREAM) {
			connectionObj[i].ns2.close();
			connectionObj[i].ns2 = null;
		}
		connectionObj[i].display = -1;
		connectionObj[i].force_close_display = false;
		connectionObj[i].client = -1;
		connectionObj[i].connected = false;
	}
	//removeFromUserList(clientid);
}

// clear incorrect users
private function closeNullUserConnection(clientid:int):void {
	var i:int = getClientConnection(clientid);
	if (i != 1) {
		myDebug("closeNullUserConnection - conn:" + i + ", clientid:" + clientid);
		closeVideo(connectionObj[i].display);
		
		// clear connection
		connectionObj[i].ns.close();
		connectionObj[i].ns = null;
		if (SEPARATE_VIDEO_STREAM) {
			connectionObj[i].ns2.close();
			connectionObj[i].ns2 = null;
		}
		connectionObj[i].display = -1;
		connectionObj[i].force_close_display = false;
		connectionObj[i].client = -1;
		connectionObj[i].connected = false;
	}
}

//------------------------------------------------------------------------------//			
private function connectionSuccessHandler(event:Event):void {
	myDebug("connected to server using .. " + connected_protocol);
	
	// get the current time
	nc.call('getTime', new Responder(getCurrentTime));
	myDebug("NC.call : getTime");
	
	clearTimeout(rtmpTimeOutID);
	rtmpTimeOutID = 0;
	
	if (reconnectTimeID != 0) {  //Remove setInterval
		myDebug("clear reconnection timer");
		clearInterval(reconnectTimeID);
		reconnectTimeID = 0;
		reconnectCount = 0;
	}
	
	// set login flag
	is_logging_in = true;
	btnLogin.enabled = true;
	btnLogin.label = resourceManager.getString('meeting_messages', 'logout');
	
	loging_name = txtUser.text;
	
	txtUser.enabled = false;
	meetingArea.enabled = true;
	videoSection.enabled = true;
	detailArea.enabled = true;
	layoutControl.enabled = true;
	qualityList.setFocus();
	
	// Get Server Client ID
	clientID = nc.clientID;
	
	// start a global timer 
	globalTimeCounter = 0;
	globalTimer = new Timer(1000); // 1 second
	globalTimer.addEventListener(TimerEvent.TIMER, taskSchedule); 
	globalTimer.start();
	
	// waiting for establish
	wait(500);
	
	// Make SO and other Connection calls
	createShareObject();
	
	// create stream connection
	createNetStream();
	
	// ENTER key for sending chat message - 20121203 //
	if(txtMsg != null) {
		txtMsg.addEventListener(FlexEvent.ENTER, txtMsgEnterHandler);
	}
	
	shareFileRefList = new FileReferenceList();
	shareFileRefList.addEventListener(Event.SELECT, shareFileHandler);
}

// ENTER key for sending chat message - 20121203 //
protected function txtMsgEnterHandler(event:FlexEvent):void{
	sendMessage(txtMsg.text, cmpColorPicker.selectedColor.toString(16));
	txtMsg.setFocus();
}

private function createNetStream():void {
	myDebug("createNetStream");
	
	var h264Settings:H264VideoStreamSettings = new H264VideoStreamSettings();  
	h264Settings.setProfileLevel(H264_PROFILE, H264_LEVEL);
	
	// establish a stream for sending 
	connectionObj[CONN_INDEX_SENDER].ns = new NetStream(nc);
	connectionObj[CONN_INDEX_SENDER].ns.bufferTime = SEND_BUFFER_TIME; //Set Buffer time, 0 means minimum delay
	if (H264_VIDEO_CODEC) {
		connectionObj[CONN_INDEX_SENDER].ns.videoStreamSettings = h264Settings; // Set H264 Encoding
		connectionObj[CONN_INDEX_SENDER].ns.publish("B" + clientID.toString() + ".f4v", "live");
		//myDebug("CODEC: " + connectionObj[CONN_INDEX_SENDER].ns.videoStreamSettings.codec);
	} else {
		connectionObj[CONN_INDEX_SENDER].ns.publish("B" + clientID.toString(), "live");
		//myDebug("CODEC: " + connectionObj[CONN_INDEX_SENDER].ns.videoStreamSettings.codec);
	}
	
	if (SEPARATE_VIDEO_STREAM) {
		connectionObj[CONN_INDEX_SENDER].ns2 = new NetStream(nc);
		connectionObj[CONN_INDEX_SENDER].ns2.bufferTime = SEND_BUFFER_TIME; //Set Buffer time, 0 means minimum delay
		if (H264_VIDEO_CODEC) {
			connectionObj[CONN_INDEX_SENDER].ns2.videoStreamSettings = h264Settings; // Set H264 Encoding
			connectionObj[CONN_INDEX_SENDER].ns2.publish("V" + clientID.toString() + ".f4v", "live");
			//myDebug("CODEC: " + connectionObj[CONN_INDEX_SENDER].ns2.videoStreamSettings.codec);	
		} else {
			connectionObj[CONN_INDEX_SENDER].ns2.publish("V" + clientID.toString(), "live");
			//myDebug("CODEC: " + connectionObj[CONN_INDEX_SENDER].ns2.videoStreamSettings.codec);
		}
	}
	
	//make sure for network connectionObj, connect to devices
	//wait(100);
	// Initial meeting devices and avtivate braodcast
	// set default of devices (opposite data, use toggle technique)
	if (!is_auto_reconnection) {
		is_cam_on = false; // disable camera by default
		is_mic_on = false; // disable microphone by default
		is_spkr_on = false;
	}
	detectDevices();
	spkrToggleManagement();	
	
	if (is_auto_reconnection && is_cam_on) {
		camToggleManagement(true);
	}
	if (is_auto_reconnection && is_mic_on) {
		micToggleManagement(true);
	}
}

private function createShareObject():void {
	myDebug("createShareObject");
	
	so_meeting = SharedObject.getRemote("meeting", nc.uri, true);
	so_meeting.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
	so_meeting.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
	so_meeting.addEventListener(SyncEvent.SYNC, sharedObjectSyncHandler);
	so_meeting.client = this;
	so_meeting.connect(nc);
	
	so_lecture = SharedObject.getRemote("lecture", nc.uri, true);
//	so_lecture.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
//	so_lecture.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
//	so_lecture.addEventListener(SyncEvent.SYNC, sharedObjectSyncHandler);
	so_lecture.client = this;
	so_lecture.connect(nc);
	
	// Get the names for all the connected users
	if (!PRE_DOWNLOAD_SLIDE) {
		so_meeting.send("getLoginName");
	}
	
	this.connectToWhiteboard(); // check the whiteboard
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

private function onMetaData(data:Object):void {
	
}

private function onNetStatus(evt:NetStatusEvent, clientid:int):void {
	//myDebug("onNetStatus - index:" + evt.info.code + ", target:" + evt.target);
	switch(evt.info.code) {
		case "NetStream.Play.UnpublishNotify":
			myDebug("NetStream.Play.UnpublishNotify -- clientid = " + clientid);
			// clear connection on local
			removeFromUserList(clientid, clientID);
			updateMeetingEnvironment();
			closeConnection(clientid);
			break;
		case "NetConnection.Connect.Rejected":
			myDebug("NetConnection.Connect.Rejected");
			break;
		default:
	}
}

/**
 * function for passming variable (client id) to network event listener 
 * http://stackoverflow.com/questions/6406957/how-to-pass-arguments-into-event-listener-function-in-flex-actionscript
 **/
private function onNetStatusX(clientid:int):Function {
	return function(evt:NetStatusEvent):void {
		onNetStatus(evt, clientid);
	};
}

private function resetEnvironment():void {
	var i:int;
	
	// Clear out User array
	meetingUsers = new Array();
	loging_number = 0;
	loging_count = 0;
	
	// initial connectionObj variables
	// 0 - sender
	// 1 - echo test
	connectionObj = new Array();
	for (i = 0; i < MAX_CONNECTIONS; i++) {
		var cobj:Object = new Object();
		cobj.ns = null; // NetStream connectionObj
		if (SEPARATE_VIDEO_STREAM) {
			cobj.ns2 = null; // NetStream connectionObj
		}
		//cobj.cam = false;	// camera
		//cobj.mic = false;	// microphone
		cobj.display = -1;	// Display index
		cobj.force_close_display = false;	// flag for force close by user
		cobj.client = -1;	// client id
		cobj.connected = false;	// connected status
		
		connectionObj.push(cobj);
	}
	
	// initial display variables
	displayObj = new Array();
	for (i = 0; i < MAX_DISPLAYS; i++) {
		var dobj:Object = new Object();
		dobj.vid = null; // new Object();	// Video Display object
		dobj.enlarge = false;	// enlarge status
		dobj.connection = -1;	// connection index
		dobj.connected = false;	// connected status
		if (i == 0) dobj.window = window1;
		if (i == 1) dobj.window = window2;
		if (i == 2) dobj.window = window3;
		if (i == 3) dobj.window = window4;
		//dobj.window.setStyle("headerHeight", 20);
		dobj.window.titleDisplay.height = 20; // http://blog.flexexamples.com/2010/07/25/setting-the-header-height-on-a-spark-panel-container-in-flex-4/
		dobj.window.closeButton.visible = false;
		dobj.window.doubleClickEnabled = false;
		dobj.old_w = dobj.window.width;
		dobj.old_h = dobj.window.height;
		dobj.old_x = dobj.window.x;
		dobj.old_y = dobj.window.y;
		
		displayObj.push(dobj);
	}
	//displayList.dataProvider = displayObj;
	
	camControl.setStyle("icon", icon_cam_off);
	camControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_cam_on');
	micControl.setStyle("icon", icon_mic_off);
	micControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_mic_on');
	echoControl.setStyle("icon", icon_echo_off);
	echoControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_echo_on');
	spkrControl.setStyle("icon", icon_spkr_off);
	spkrControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_spkr_on');
	kickout.setStyle("icon", icon_kickout_off);
	kickout.toolTip = resourceManager.getString('meeting_messages', 'tooltip_kickout');
	micMuteUser.setStyle("icon", icon_mute_mic_off);
	micMuteUser.toolTip = resourceManager.getString('meeting_messages', 'tooltip_mute_mic');
	micMuteAllUser.setStyle("icon", icon_muteall_mic_off);
	micMuteAllUser.toolTip = resourceManager.getString('meeting_messages', 'tooltip_muteall_mic');
	camBlockUser.setStyle("icon", icon_block_cam_off);
	camBlockUser.toolTip = resourceManager.getString('meeting_messages', 'tooltip_block_cam');
	camBlockAllUser.setStyle("icon", icon_blockall_cam_off);
	camBlockAllUser.toolTip = resourceManager.getString('meeting_messages', 'tooltip_blockall_cam');
	
	rtmpTimeOutID = 0;
	//reconnectTimeID = 0;
	//reconnectCount = 0;
	
	// set quality option
	qualityMode = qualityList.selectedIndex;
	
	is_admin = false;
	is_admin_kick = false; //false means system can be login-ed
	is_admin_mute_mic = false;
	is_admin_block_cam = false;
	is_mainvideo = false;
	is_shared_display = false;
	lstUsers.dataProvider = null;
	//meetingPanel.title = resourceManager.getString('meeting_messages', 'panel_title');
	
	txtUser.enabled = true;
	devicesQuality.enabled = true;
	userArea.enabled = true;
	layoutControl.enabled = false;
	videoSection.enabled = false;
	detailArea.enabled = false;
	adminControl.visible = false;
	adminControl.enabled = false;
	admin.selected = false;
	
	// admin function available only for member; disabled for guest
	if(userClass == "1") {
		admin.enabled = true;
		admin.label = resourceManager.getString('meeting_messages', 'label_admin');
	} else {
		admin.enabled = false;
		admin.label = resourceManager.getString('meeting_messages', 'label_admin_guest');
	}
	
	//20121212
	sharedDisplay.selected = false;
	is_shared_display = false;
	
	if (!is_auto_reconnection) {
		is_cam_on = false;
		is_mic_on = false;
		is_echo_on = false;
		is_spkr_on = false;
	}
	is_first_connect = true;
	is_logging_in = false;	
}

private function cleanUp():void {
	if(is_logging_in){
		is_auto_reconnection = false;
		meetingLogout();
	}
}

private function loginManagement():void {
	//myDebug("loginManagement : " + is_logging_in);
	
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
	resetEnvironment();
	//initAutoReconnecting();
	
	is_close_connection = false;
	
	NetConnection.defaultObjectEncoding = flash.net.ObjectEncoding.AMF0;
	SharedObject.defaultObjectEncoding  = flash.net.ObjectEncoding.AMF0;
	
	lstUsers.addEventListener(ListEvent.ITEM_DOUBLE_CLICK, openVideo, false, EventPriority.DEFAULT_HANDLER);
 
	if(txtUser.text != "" && !is_admin_kick) {
		nc = new FMSConnection();
//		nc.client = new CustomClient(); //It may no needed 
		nc.addEventListener("success", connectionSuccessHandler);
		nc.addEventListener("falied", connectionFailed);
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
	is_logging_in = false;
	
	// clear shared video display
	if(is_admin && is_shared_display){
		so_meeting.send("doReleaseSharedVideoDisplay", clientID);
		myDebug("SO.send : doReleaseSharedVideoDisplay");
	}
	is_shared_display = false; //20130108
	
	// update presenter video status for lecture client
	if (ENABLE_LECTURE_CLIENT) {
		if (is_presenter) {
			nc.call("setPresenterID", null, 0 , false);
			myDebug("NC.call : setPresenterID");
			so_lecture.send("updateVideoData", 0, false);
			myDebug("SO_lecture.send : updateVideoData");
		}
	}
	
	// to close the user video on remote site when logout
	if(is_cam_on){
		so_meeting.send("closeVideoPanel", clientID);
		myDebug("SO.send : closeVideoPanel");
	}
	
	this.disconnectWhiteboard();

  	// Close Connections
  	clearMicActivity();   
	clearTimeout(rtmpTimeOutID);
	PopUpManager.removePopUp(echoTestBox);
	PopUpManager.removePopUp(userManagementPanel);
	
	/*** use function from netstream unpublish notify instead
	// send messages to clear on other clients
	so_meeting.send("removeFromUserList", clientID, clientID);
	so_meeting.send("updateMeetingEnvironment");
	so_meeting.send("closeConnection", clientID);
	***/
	
	for (var i:int = 0; i < MAX_DISPLAYS; i++) {
		enlargeDisplay(i, true);  // return to the default layout
 		displayObj[i].window.title = "";
 		displayObj[i].window.removeAllElements();
  		displayObj[i].window.closeButton.visible = false;
		displayObj[i].window.doubleClickEnabled = false;
		// release an attachment of camera and video object
		if (displayObj[i].vid) {
			// the video object is should be the latest children from function "doDisplayVideo"
			for (var j:int = displayObj[i].vid.numChildren - 1; j >= 0; j--) {
				var child:Object = displayObj[i].vid.getChildAt(j);
				if(child is Video) {
					(child as Video).attachCamera(null);
					(child as Video).attachNetStream(null);
				}
			}
		}
 		displayObj[i].vid = null;
 		displayObj[i].connection = -1;
 		displayObj[i].connected = false;
 	}
	
	btnLogin.enabled = true;
	btnLogin.label = resourceManager.getString('meeting_messages', 'login');
		
	// delay for closing connection
	is_close_connection = true;
} 

// deley for closing connection
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
		connectionObj[i].client = -1;
		connectionObj[i].connected = false;
	}
	
	// close sharedobject
	if (so_meeting != null) {
		so_meeting.close();
	}
	so_meeting = null;
	
	// close connection
	nc.close();
	nc = null;
	
	resetEnvironment();
	
	globalTimer.stop();
	globalTimer = null;
}

public function getLoginName():void {
	myDebug("SO.recv : getLoginName");
	
	// Clear out User array
	meetingUsers = new Array();
	loging_number = 0;
	loging_count = 0;
	
	// get the number of logging users
	nc.call('getSize', new Responder(getLogingNumber));
	myDebug("NC.call : getSize");
	
	// Getting Users name is basically forcing each connected user to re-send their name
	so_meeting.send("updateUserList", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
	myDebug("SO.send : updateUserList");
	
}

// get the number of logging users
private function getLogingNumber(size:int):void {
	myDebug("NC.responder : getSize");
	loging_number = size;
	myDebug("getLogingNumber - number of loging users : " + loging_number);
	
	if (loging_count >= loging_number) {
		postLoginProcesses();
	}
}

// get the current time
private function getCurrentTime(time:Number):void {
	time = time * 1000;
	var date:Date = new Date(time);
	loginTime = dateFormatter.format(date);
	myDebug("getCurrentTime : getDate - " + date);
}

public function updateUserList(name:String, clientid:Number, userclass:String, ltime:String, cam:Boolean, mic:Boolean, admin:Boolean, mute:Boolean, block:Boolean, mainvideo:Boolean, presenter:Boolean = false, chairman:Boolean = false):void {
	// initialize
	if(meetingUsers == null) {
		meetingUsers = new Array();
	}
	
	var status:String = getStatusString(cam, mic, mute, block);
	userclass = (userclass == "1") ? (resourceManager.getString('meeting_messages', 'label_user_class_member')) : (resourceManager.getString('meeting_messages', 'label_user_class_guest'));
	myDebug("SO.recv : updateUserList : " + name + ":" + clientid + ":" + userclass + ":" + ltime + ":" + cam + ":" + mic + ":" + admin + ":" + mute + ":" + block + ":" + mainvideo + ":" + presenter + ":" + chairman + ":" + status);
	meetingUsers.push({ loginname:name, uname:name, clientid:clientid, userclass:userclass, logintime:ltime, status:status, cam:cam, mic:mic, admin:admin, mainvideo:mainvideo, presenter:presenter, chairman:chairman });
	
	// Sort Users by client id
	//meetingUsers.sortOn("clientid", Array.CASEINSENSITIVE);
	
	dpUsers = new ArrayCollection(meetingUsers);
	
	if (userManagementPanel) {
		userManagementPanel.updateData(dpUsers); 
	}
	
	// count users in the list 
	loging_count++;
	if (loging_count >= loging_number && loging_number > 0) {
		postLoginProcesses();
	}
}

public function updateUserListStatus(name:String, clientid:Number, userclass:String, ltime:String, cam:Boolean, mic:Boolean, admin:Boolean, mute:Boolean = false, block:Boolean = false, mainvideo:Boolean = false, presenter:Boolean = false, chairman:Boolean = false):void {
	myDebug("SO.recv : updateUserListStatus");
	if(meetingUsers == null) {
		meetingUsers = new Array();
	}
	
	for(var i:int = 0; i < meetingUsers.length; i++) {
		//myDebug("updateUserListStatus id : " + i + ":" + meetingUsers[i].clientid + ":" + meetingUsers[i].name);

		if (meetingUsers[i].clientid == clientid){
			var status:String = getStatusString(cam, mic, mute, block);
			userclass = (userclass == "1") ? (resourceManager.getString('meeting_messages', 'label_user_class_member')) : (resourceManager.getString('meeting_messages', 'label_user_class_guest'));
			myDebug("updateUserListStatus : " + name + ":" + clientid + ":" + userclass + ":" + ltime + ":" + cam + ":" + mic + ":" + admin + ":" + mute + ":" + block + ":" + mainvideo + ":" + presenter + ":" + chairman + ":" + status);
			meetingUsers[i].loginname = name;
			meetingUsers[i].uname = name;
			meetingUsers[i].clientid = clientid;
			meetingUsers[i].userclass = userclass;
			meetingUsers[i].logintime = ltime;
			meetingUsers[i].status = status;
			meetingUsers[i].cam = cam;
			meetingUsers[i].mic = mic;
			meetingUsers[i].admin = admin;
			meetingUsers[i].mainvideo = mainvideo;
			meetingUsers[i].presenter = presenter;
			meetingUsers[i].chairman = chairman;
			
			// update broadcat video panel
			playBroadcastingStream(clientid, name, (cam && !block));
			
			break;
		}
	}
	
	dpUsers = new ArrayCollection(meetingUsers);
	updateMeetingEnvironment();
	
	if (userManagementPanel) {
		userManagementPanel.updateData(dpUsers); 
	}	
}

public function removeFromUserList(removeid:Number, clientid:Number):void {
	if (clientid == clientID) {
		myDebug("SO.recv : removeFromUserList : " + removeid + ":"+ meetingUsers.length);
	
		for(var i:int = 0; i < meetingUsers.length;i++) {
			if(meetingUsers[i].clientid == removeid) {
				myDebug("remove id : " + i + ":" + removeid + ":"+meetingUsers[i].clientid+ ":"+meetingUsers[i].loginname);
				var uname:String = getClientName(removeid);
				if (uname != null) {
					NotificatorManager.show("'" + uname + "' " + resourceManager.getString('meeting_messages', 'is_disconnected'), NotificatorMode.WARNING, noticsDuration);
				}
				meetingUsers.splice(i, 1);
			}
		}
		// Sort Users
		//meetingUsers.sortOn("clientid", Array.CASEINSENSITIVE);
		
		dpUsers = new ArrayCollection(meetingUsers);
		
		if (userManagementPanel) {
			userManagementPanel.updateData(dpUsers); 
		}
	}
}

// do any important processes after logged-in
private function postLoginProcesses(): void {
	myDebug("postLoginProcesses");
	connectBroadcastingStreams();
	updateMeetingEnvironment();
	
	// update shared display view
	if (is_admin && is_shared_display) {
		sharedDisplay_toggle();
	}
}

// update the latest environment
private function updateMeetingEnvironment(): void {
	myDebug("updateMeetingEnvironment");
	
	checkAdmin();
	checkChairman();
	checkPresenter();
	//checkMainvideo();
	updateUserDetails();
	updateWbButtons();
	
	if (is_first_connect && is_shared_display) {
		myDebug("call updateSharedVideoDisplay");
		updateSharedVideoDisplay();
	}
	
	is_first_connect = false;
}

private function changeQualityFromList():void {
	if (qualityList.selectedIndex == 0) {
		camControl.enabled = false;
		micControl.enabled = false;
	}
	else {
		changeQuality(qualityList.selectedIndex);
		
		camControl.enabled = true;
		micControl.enabled = true;
	}
}

private function changeQuality(mode:int):void {
	//qualityMode = (mode > 0) ? mode : qualityMode;
	//qualityMode = mode;
	//myDebug("change quality : " + qualityMode.toString());
	if (is_logging_in && qualityMode != mode) {
		qualityMode = mode;
		myDebug("change quality : " + qualityMode.toString());
		
		// force to turn of camera when using Ultra-Low mode
		if (qualityMode == 1) {
			stopCamera();
			
			//Send Broadcast Message to inform the situation
			so_meeting.send("updateUserListStatus", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
			myDebug("SO.send : updateUserListStatus");
		}
		else {
			camToggleManagement(true);
		}
		micToggleManagement(true);
		
		if (is_cam_on) {
			myCam.setMode(qualityArray[qualityMode].w, qualityArray[qualityMode].h, qualityArray[qualityMode].f);
			myCam.setQuality(0, qualityArray[qualityMode].q);
		}
		if (is_mic_on) {
			myMic.rate = qualityArray[qualityMode].s;
		}
	}
}

private function detectDevices():void {
	// detect camera
	if (myCam == null) {
		myCam = Camera.getCamera();
	}
	if (myCam == null) {
		camControl.setStyle("icon", icon_cam_none);
		camControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_no_device');
		is_cam_on = false;
	}
	
	//detect microphone
	if (myMic == null) {
		myMic = Microphone.getMicrophone();
	}
	if (myMic == null) {
		micControl.setStyle("icon", icon_mic_none);
		micControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_no_device');
		is_mic_on = false;
	}
}

private function camToggleManagement(force_on:Boolean = false):void {
	var old_cam_status:Boolean = is_cam_on;
	// force to turn of camera when using Ultra-Low mode
	if ((!is_cam_on && qualityMode > 1) || force_on) {
		startCamera(force_on);
	}
	else {
		stopCamera();
	}
	
	if (old_cam_status != is_cam_on) {
		//Send Broadcast Message to inform the situation
		so_meeting.send("updateUserListStatus", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
		myDebug("SO.send : updateUserListStatus");
	}
}

////////////////////Insert Video Function/////////////////////////////////////
private function startCamera(force_on:Boolean = false):void {
	myDebug("startCamera");
	if (myCam == null) {
		myCam = Camera.getCamera();
	}
	
	if (myCam != null) {
		if (!is_cam_on || force_on) {
			myCam.setMode(qualityArray[qualityMode].w, qualityArray[qualityMode].h, qualityArray[qualityMode].f);
			myCam.setQuality(0, qualityArray[qualityMode].q);
			
			if (!is_admin_block_cam) {
				myDebug("attach cam");
				// display local video
				playLocalVideo();
		    	// broadcast a video
				if (SEPARATE_VIDEO_STREAM) {
	    			connectionObj[CONN_INDEX_SENDER].ns2.attachCamera(myCam);
				}
				else {
					connectionObj[CONN_INDEX_SENDER].ns.attachCamera(myCam);
				}
				// update presenter video status for lecture client
				if (ENABLE_LECTURE_CLIENT) {
					if (is_presenter) {
						nc.call("setPresenterID", null, clientID, true);
						myDebug("NC.call : setPresenterID");
						so_lecture.send("updateVideoData",clientID, true);
						myDebug("SO_lecture.send : updateVideoData");
					}
				}
			}
			else {
				myDebug("block by admin");
				if (SEPARATE_VIDEO_STREAM) {
					connectionObj[CONN_INDEX_SENDER].ns2.attachCamera(null);
				}
				else {
					connectionObj[CONN_INDEX_SENDER].ns.attachCamera(null);
				}
			}
			
			camControl.setStyle("icon", icon_cam_on);
			camControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_cam_off');
			is_cam_on = true;
		}
	}
	else {
		camControl.setStyle("icon", icon_cam_none);
		camControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_no_device');
		is_cam_on = false;
	}
	//20121212 - call shared video display when admin restarts a camera on local
	if (is_admin && is_shared_display) {
		sharedDisplay_toggle();
	}
}

private function stopCamera():void {  //Stop Broadcast
	myDebug("stopCamera");
	// clear camera
	if (myCam != null) {
		myCam = null;
	}
	
	so_meeting.send("closeVideoPanel", clientID);
	myDebug("SO.send : closeVideoPanel");
	
	camControl.setStyle("icon", icon_cam_off);
	camControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_cam_on');
	is_cam_on = false;
	
	if (SEPARATE_VIDEO_STREAM) {
		connectionObj[CONN_INDEX_SENDER].ns2.attachCamera(null);
	}
	else {
		connectionObj[CONN_INDEX_SENDER].ns.attachCamera(null);
	}
	
	// update presenter video status for lecture client
	if (ENABLE_LECTURE_CLIENT) {
		if (is_presenter) {
			nc.call("setPresenterID", null, clientID, false);
			myDebug("NC.call : setPresenterID");
			so_lecture.send("updateVideoData", clientID, false);
			myDebug("SO_lecture.send : updateVideoData");
		}
	}
}
 
private function micToggleManagement(force_on:Boolean = false):void {
	var old_mic_status:Boolean = is_mic_on;
	if (!is_mic_on || force_on) {
		startMicrophone(force_on);
	}
	else {
		stopMicrophone();
	}
	
	if (old_mic_status != is_mic_on) {
		//Send Broadcast Message to inform the situation
		so_meeting.send("updateUserListStatus", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
		myDebug("SO.send : updateUserListStatus");
	}
}

private function startMicrophone(force_on:Boolean = false):void {
	if (myMic == null) {
		myMic = Microphone.getMicrophone();
	}
	
	if (myMic != null) {
		if (!is_mic_on || force_on) {
			myMic.setUseEchoSuppression(true);
			//myMic.setSilenceLevel(0,5000);
			myMic.setSilenceLevel(0);
			//myMic.codec=SoundCodec.SPEEX; move comment out when use speex codec 2010-03-18
			myMic.rate = qualityArray[qualityMode].s;
			
			// share voice
			if (!is_admin_mute_mic) {
				myDebug("attach mic");
				myMic.gain = microphoneSlider.value;
				// publish
				connectionObj[CONN_INDEX_SENDER].ns.attachAudio(myMic);
			}
			else {
				myDebug("mute by admin");
				myMic.gain = 0;
				connectionObj[CONN_INDEX_SENDER].ns.attachAudio(null);
			}
					
			micTimer.addEventListener(TimerEvent.TIMER, showMicActivity); 
			micTimer.start();
			
			micControl.setStyle("icon", icon_mic_on);
			micControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_mic_off');
			is_mic_on = true;
		}
	}
	else {
		micControl.setStyle("icon", icon_mic_none);
		micControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_no_device');
		is_mic_on = false;
	}
}

private function stopMicrophone():void {  //Stop Sound (Mute)
	clearMicActivity();
	myDebug("stopMicrophone");
	if (myMic != null) {	
		myMic.gain = 0;  // mute
		myMic = null;
	}
	
	micControl.setStyle("icon", icon_mic_off);
	micControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_mic_on');
	is_mic_on = false;
		
	connectionObj[CONN_INDEX_SENDER].ns.attachAudio(null);
}

private function spkrToggleManagement():void {
	myDebug("spkrToggleManagement");
	//**** modifiy later
//	is_spkr_on = false;
	if (!is_spkr_on) {
		startSpeaker();
		spkrControl.setStyle("icon", icon_spkr_on);
		spkrControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_spkr_off');
		is_spkr_on = true;
	}
	else {
		stopSpeaker();
		spkrControl.setStyle("icon", icon_spkr_off);
		spkrControl.toolTip = resourceManager.getString('meeting_messages', 'tooltip_spkr_on');
		is_spkr_on = false;
	}
}


private function startSpeaker():void {
	myDebug("startSpeaker"); 
	
	nsst.volume = speakerSlider.value * 0.01;
	for (var i:int = 0; i < MAX_CONNECTIONS; i++) {
		if (connectionObj[i].ns) {
			connectionObj[i].ns.soundTransform = nsst;
		}
	}
	
}

private function stopSpeaker():void {
	myDebug("stopSpeaker"); 
	
	nsst.volume = 0;
	for (var i:int = 0; i < MAX_CONNECTIONS; i++) {
		if (connectionObj[i].ns) {
			connectionObj[i].ns.soundTransform = nsst;
		}
	}
	
}

private function connectBroadcastingStreams():void {
	myDebug("connectBroadcastingStreams");
	for(var i:int = 0; i < meetingUsers.length;i++) {
		playBroadcastingStream(meetingUsers[i].clientid, meetingUsers[i].loginname, meetingUsers[i].cam);
	}
}

private function playBroadcastingStream(clientid:Number, titleName:String, client_cam:Boolean, open_by_list:Boolean = false):void {
	if(clientid != clientID){
		myDebug("playBroadcastingStream - title:" + titleName + ", clientid:" + clientid);
		var avail:Boolean = false;
		var isNewConn:Boolean = true;
		var isNewDisp:Boolean = true;
		var i:int;
		var cIdx:int;
		
		// confirm that is the new connection
		i = getClientConnection(clientid);
		if (i != -1) {
			myDebug("playBroadcastingStream - found existing conn:" + i);
			isNewConn = false;
			cIdx = i;	// keep a connection index.
		}
		
		// if new connection,
		// find the available connection
		if (isNewConn) {
			for (i = (CONN_INDEX_SENDER + 1); i < MAX_CONNECTIONS; i++) {
				if (!connectionObj[i].connected) {
					cIdx = i;
					avail = true;
					break;
				}
			}
			
			if (avail) {
				myDebug("playBroadcastingStream - new conn:" + i);
				connectionObj[cIdx].ns = new NetStream(nc);
				connectionObj[cIdx].ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStatusX(clientid));
				connectionObj[cIdx].ns.bufferTime = RECV_BUFFER_TIME; //Set Buffer time, 0 means minimum delay
				// http://livedocs.adobe.com/flashmediaserver/3.0/hpdocs/help.html?content=00000191.html    // For ns.publish() - The default value for bufferTime is 9.
				// http://livedocs.adobe.com/flashmediaserver/3.0/hpdocs/help.html?content=00000185.html    // For ns.play() - The buffer time must be at least 0.1 seconds, but it can be higher.
				// http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/net/NetStream.html#bufferTime  //Live content - When streaming live content, set the bufferTime property to 0.
				/* Flash Media Server. The buffer behavior depends on whether the buffer time is set on a publishing stream or a subscribing stream. 
				For a publishing stream, bufferTime specifies how long the outgoing buffer can grow before the application starts dropping frames. 
				On a high-speed connection, buffer time is not a concern; data is sent almost as quickly as the application can buffer it. 
				On a slow connection, however, there can be a significant difference between how fast the application buffers the data and how fast it is sent to the client. 
				For a subscribing stream, this method specifies how long to buffer incoming data before starting to display the stream. 
				For example, if you want to make sure that the first 15 seconds of the stream play without interruption, set bufferTime to 15; 
				Flash Player begins playing the stream only after 15 seconds of data have been buffered.
				*/
				
				if(H264_VIDEO_CODEC) {
					connectionObj[cIdx].ns.play("B"+clientid+".f4v",-1);
				} else {
					connectionObj[cIdx].ns.play("B"+clientid,-1);
				}	
				connectionObj[cIdx].client = clientid;
				connectionObj[cIdx].connected = true;
			}
		}
		
		// clear close flag when open from list (double click)
		//if (open_by_list || is_shared_display) {
		if (open_by_list) {
			connectionObj[cIdx].force_close_display = false;
		}
		
		if (client_cam) {
			// confirm that is the new display
			isNewDisp = false;
			var freeDis:int = MAX_DISPLAYS;
			var isConnecting:Boolean = false;
			for (i = 0; i < MAX_DISPLAYS; i++) {
				if (displayObj[i].connected) {
					//myDebug("display : " + i + " is connected");
					// skip if still connecting
					if (displayObj[i].connection == cIdx) {
						isConnecting = true;
						break;
					}
					freeDis--;
				}
			}
			//myDebug("freeDis : " + freeDis + ", isConnecting = " + isConnecting);
			if (freeDis > 0 && !isConnecting && !connectionObj[cIdx].force_close_display) {
				myDebug("playBroadcastingStream - found available display");
				isNewDisp = true;
			}
			
			// if new display,
			// find the available display
			if (isNewDisp) {
				displayVideo(cIdx, clientid, titleName, false, null, connectionObj[cIdx].ns);
			}
		}
	}
}

private function displayVideo(connection:int, client:int, title:String, is_local:Boolean = false, local_cam:Camera = null, ns:NetStream = null, fix_display:int = -1):void {
	if (SEPARATE_VIDEO_STREAM && !is_local) {
		myDebug("open video stream : conn = " + connection + ", id = " + client);
		connectionObj[connection].ns2 = new NetStream(nc);
		connectionObj[connection].ns2.bufferTime = RECV_BUFFER_TIME; //Set Buffer time, 0 means minimum delay
		// http://livedocs.adobe.com/flashmediaserver/3.0/hpdocs/help.html?content=00000191.html    // For ns.publish() - The default value for bufferTime is 9.
		// http://livedocs.adobe.com/flashmediaserver/3.0/hpdocs/help.html?content=00000185.html    // For ns.play() - The buffer time must be at least 0.1 seconds, but it can be higher.
		// http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/net/NetStream.html#bufferTime  //Live content - When streaming live content, set the bufferTime property to 0.
		/* Flash Media Server. The buffer behavior depends on whether the buffer time is set on a publishing stream or a subscribing stream. 
		For a publishing stream, bufferTime specifies how long the outgoing buffer can grow before the application starts dropping frames. 
		On a high-speed connection, buffer time is not a concern; data is sent almost as quickly as the application can buffer it. 
		On a slow connection, however, there can be a significant difference between how fast the application buffers the data and how fast it is sent to the client. 
		For a subscribing stream, this method specifies how long to buffer incoming data before starting to display the stream. 
		For example, if you want to make sure that the first 15 seconds of the stream play without interruption, set bufferTime to 15; 
		Flash Player begins playing the stream only after 15 seconds of data have been buffered.
		*/
		
		if(H264_VIDEO_CODEC){
			connectionObj[connection].ns2.play("V"+client+".f4v",-1);
		} else {
			connectionObj[connection].ns2.play("V"+client,-1);
		}
		doDisplayVideo(connection, client, title, is_local, local_cam, connectionObj[connection].ns2, fix_display);
	}
	else {
		doDisplayVideo(connection, client, title, is_local, local_cam, ns, fix_display);
	}
}

private function doDisplayVideo(connection:int, client:int, title:String, is_local:Boolean = false, local_cam:Camera = null, ns:NetStream = null, fix_display:int = -1):void {
	var i:int;
	var avail:Boolean = false;
	for (i = 0; i < MAX_DISPLAYS; i++) {
		// fix display index is checked 
		if (fix_display >= 0 && fix_display != i) {
			continue;
		}
		
		if (!displayObj[i].connected) {
			myDebug("displayVideo - vid:" + i + ", conn:" + connection);
			
			// calculate a video display size
			var vidWidth:int = displayObj[i].window.width - 2; // - displayObj[i].window.getStyle("borderThicknessRight") - displayObj[i].window.getStyle("paddingLeft") - displayObj[i].window.getStyle("paddingRight");
			var vidHeight:int = displayObj[i].window.height - displayObj[i].window.titleDisplay.height - 2; // - displayObj[i].window.getStyle("headerHeight");// - displayObj[i].window.getStyle("borderThicknessTop") - displayObj[i].window.getStyle("borderThicknessBottom") - displayObj[i].window.getStyle("paddingTop") - displayObj[i].window.getStyle("paddingBottom");
			var vid:Video = new Video(vidWidth, vidHeight);
			//vid.width = vidWidth;
			//vid.height = vidHeight;
			
			if (is_local) {
				vid.attachCamera(local_cam);
			}
			else {
				vid.attachNetStream(ns);
			}
				
			displayObj[i].vid = new VideoDisplay();
			displayObj[i].vid.percentHeight = 100;
			displayObj[i].vid.percentWidth = 100;
			displayObj[i].vid.addChild(vid);
			
			displayObj[i].window.addElement(displayObj[i].vid);
			displayObj[i].window.title = title;
			displayObj[i].window.closeButton.visible = true;
			displayObj[i].window.doubleClickEnabled = true;
			
			displayObj[i].connection = connection;
			displayObj[i].connected = true;
			
			// initial framerate message
			var framerateMsg:Text = new Text();
			framerateMsg.setStyle("color", "#ff0000");
			framerateMsg.text = "";
			displayObj[i].window.addElement(framerateMsg);
			displayObj[i].zeroFramerateCounter = new int(0);
			
			//20121212
			if (!is_admin && is_shared_display) {
				displayObj[i].window.closeButton.visible = false;
				displayObj[i].window.doubleClickEnabled = false;
			}
			/*
			else {
				displayObj[i].window.closeButton.visible = true; //20121212
			}
			*/
			
			connectionObj[connection].display = i;	// keep the display index
			connectionObj[connection].force_close_display = false;
			connectionObj[connection].client = client;
			connectionObj[connection].connected = true;
			
			avail = true;
			break;
		}
	}

	if (!avail) {
		//Notification.show(resourceManager.getString('meeting_messages', 'display_full') , noticsTitle, noticsDuration, noticsPosition, noticsIcon, noticsStack);
	}
}

private function openVideo(event:ListEvent):void {
	var selectedRow:Object = event.currentTarget.selectedItem;
	
	if (getConnectionDisplay(getClientConnection(selectedRow.clientid)) == -1) {
		myDebug("openVideo - id:" + selectedRow.clientid + ", name + " + selectedRow.loginname);
			
		if (selectedRow.clientid == clientID) {
			if (is_cam_on && !is_admin_block_cam) {
				playLocalVideo();
			}
		}
		else {
			playBroadcastingStream(selectedRow.clientid, selectedRow.loginname, (selectedRow.cam && !selectedRow.block), true); //20121225
		}
		
		//20121212 - call shared video display when admin opens a window
		if (is_admin && is_shared_display) {
			sharedDisplay_toggle();
		}
	}
}

// checking who is disconnected/////////////////////////////////////////
private function closeVideoByButton(index:int):void {
	if (displayObj[index].connected) {
		myDebug("closeVideoByButton - vid:" + index);
		connectionObj[displayObj[index].connection].force_close_display = true;
		closeVideo(index);
	}
}

private function closeVideo(index:int):void {
 	if (displayObj[index].connected) {
	 	myDebug("closeVideo - vid:" + index);
		
		if (SEPARATE_VIDEO_STREAM && displayObj[index].connection != CONN_INDEX_SENDER) {
			myDebug("close video stream : conn = " + displayObj[index].connection + ", id = " + connectionObj[displayObj[index].connection].client);
			connectionObj[displayObj[index].connection].ns2.close();
			connectionObj[displayObj[index].connection].ns2 = null;
		}
	 	// restore to  normal size
		if (displayObj[index].enlarge) {
			enlargeDisplay(index, true);
		}
		
		// clear display
	 	displayObj[index].window.title = "";
	 	displayObj[index].window.removeAllElements();
	 	displayObj[index].window.closeButton.visible = false;
		displayObj[index].window.doubleClickEnabled = false;
		// release an attachment of camera and video object
		// the video object should be the latest children from function "doDisplayVideo"
		for (var j:int = displayObj[index].vid.numChildren - 1; j >= 0; j--) {
			var child:Object = displayObj[index].vid.getChildAt(j);
			if(child is Video) {
				(child as Video).attachCamera(null);
				(child as Video).attachNetStream(null);
			}
		}
	 	displayObj[index].vid = null;
	 	displayObj[index].connection = -1;
		displayObj[index].connected = false;
	}
	
	//20121212 - for shared video display
	if (is_admin && is_shared_display){
		sharedDisplay_toggle();
	}
} 

public function closeVideoPanel(clientid:int):void {
	myDebug("SO : closeVideoPanel");
	var i:int = getClientConnection(clientid);
	if (i != -1) {
		closeVideo(connectionObj[i].display);
	}
}

private function updateUserDetails():void {
	myDebug("updateUserDetails");
	var i:int;
	var uname:String;
	
	// update users list
	for(i = 0; i < meetingUsers.length;i++) {
		uname = meetingUsers[i].loginname;
		
		uname += (meetingUsers[i].clientid == clientID) ? " {" + resourceManager.getString('meeting_messages', 'label_host') + "}" : "";
		uname += (meetingUsers[i].admin) ? " (" + resourceManager.getString('meeting_messages', 'meeting_admin') + ")" : "";
		uname += (meetingUsers[i].mainvideo) ? " <" + resourceManager.getString('meeting_messages', 'meeting_mainvideo') + ">" : "";
		uname += (meetingUsers[i].presenter) ? " <P>" : "";
		uname += (meetingUsers[i].chairman) ? " <C>" : "";
		meetingUsers[i].uname = uname;
  	}
  	
  	dpUsers = new ArrayCollection(meetingUsers);
	
	//for wide user management panel
	if (userManagementPanel) {
		userManagementPanel.updateData(dpUsers); 
	}
	
	myDebug(meetingUsers.toString());
  	// update video title
  	// move Null user name (incorrect logout)
  	if (meetingUsers.length > 0) {
		for (i = 0; i < MAX_DISPLAYS; i++) {
			if (displayObj[i].connected) {
				uname = getClientName(connectionObj[displayObj[i].connection].client);
				
				if (uname != null) {
					uname += (connectionObj[displayObj[i].connection].client == clientID) ? " {" + resourceManager.getString('meeting_messages', 'label_host') + "}" : "";
					uname += (isAdmin(connectionObj[displayObj[i].connection].client)) ? " (" + resourceManager.getString('meeting_messages', 'meeting_admin') + ")" : "";
					//uname += (isMainvideo(connectionObj[displayObj[i].connection].client)) ? " <" + resourceManager.getString('meeting_messages', 'meeting_mainvideo') + ">" : "";
					displayObj[i].window.title = uname;
				}
			}
		}
  	}
}

private function isClientCamOn(clientid:int):Boolean {
	myDebug("isClientCamOn - clientid:" + clientid);
	var iscam:Boolean = false;
	for(var i:int = 0; i < meetingUsers.length; i++) {
		if (meetingUsers[i].clientid == clientid) {
			iscam = meetingUsers[i].cam;
			
			break;
		}
	}	
	return iscam;
}

private function sendMessage(msg:String, color:String):void {
	
	if (msg != null && StringUtil.trim(msg) != "") {
		so_lecture.send("newMessage", loging_name, msg, color, clientID);			
		myDebug("SO.send : newMessage");
		// save message transaction
		nc.call('saveMessage', null, loging_name, msg, color);
		myDebug("NC.call : saveMessage");
		
		txtMsg.text = "";
		txtMsg.setFocus();
		
		if(chatFloatingPanel != null){
			chatFloatingPanel.txtMsg2.text = "";
			chatFloatingPanel.txtMsg2.setFocus();
		} 
	}
}

private function myDataTipFuncMicrophone(val:int):int {
	return int(val);
}
            
private function myDataTipFuncSpeaker(val:int):int {
	return int(val);
}

private function sliderChangeLiveMicrophone(event:Event):void {
	if (is_mic_on) {   	
		myMic.gain = microphoneSlider.value;
	}
}

private function sliderChangeLiveSpeaker(event:Event):void {
	nsst.volume = speakerSlider.value * 0.01;
	for (var i:int = 0; i < MAX_CONNECTIONS; i++) {
		if (connectionObj[i].ns) {
			connectionObj[i].ns.soundTransform = nsst;
		}
	}
}

// get connection id of client
private function getClientConnection(clientid:int):int {
	//myDebug("getClientConnection - clientid:" + clientid);
	var connection:int = -1;
	for (var i:int = 0; i < MAX_CONNECTIONS; i++) {
		if (connectionObj[i].client == clientid && connectionObj[i].connected) {
			connection = i;
			break;
		}
	}
	return connection;
}

// get display id of connection
private function getConnectionDisplay(connection:int):int {
	//myDebug("getConnectionDisplay - connection:" + connection);
	var display:int = -1;
	for (var i:int = 0; i < MAX_DISPLAYS; i++) {
		if (displayObj[i].connection == connection && displayObj[i].connected) {
			display = i;
			break;
		}
	}
	return display;
}

// get username of client
private function getClientName(clientid:int):String {
	//myDebug("getClientName - clientid:" + clientid);
	var clientname:String = null;
	for(var i:int = 0; i < meetingUsers.length; i++) {
		if (meetingUsers[i].clientid == clientid) {
			clientname = meetingUsers[i].loginname;
			
			break;
		}
	}	
	return clientname;
}

// get details from status
private function getStatusString(cam:Boolean, mic:Boolean, mute:Boolean, block:Boolean):String {
	var status:String = null;
	status = (cam) ? "Camera" : "";
	status += (cam && block) ? " (" + resourceManager.getString('meeting_messages', 'block_cam') + ")" : "";
	status += (cam && mic) ? " + " : "";
	status += (mic) ? "Mic" : "";
	status += (mic && mute) ? " (" + resourceManager.getString('meeting_messages', 'mute_mic') + ")" : "";
	return status;
}

// tasks schdules
private function taskSchedule(e:TimerEvent): void {
	// increase counter
	globalTimeCounter++;
	
	// check the network traffic every minute
	if (qualityList.selectedIndex == 0 && (globalTimeCounter % 60) == 0) {
		tsInit();
	}
	
	/*
	// check the video framerate every 3 seconds
	if ((globalTimeCounter % 3) == 0) {
		checkVideoFramerate();
	}
	*/
	
	// provide message notification
	blinkNoticeMsg();
	
	// check the logout signal
	if (is_close_connection) {
		closeNetworkConnection();
	}
}

private function checkVideoFramerate():void {
	//myDebug("checkVideoFramerate");
	for (var i:int = 0; i < MAX_DISPLAYS; i++) {
		if (displayObj[i].connected) {
			
			var framerateValue:Number = 0;
			if (displayObj[i].connection == CONN_INDEX_SENDER) {
				framerateValue = Math.round(myCam.currentFPS * 1000) / 1000;
			}
			else {
				if (SEPARATE_VIDEO_STREAM) {
					framerateValue = Math.round(connectionObj[displayObj[i].connection].ns2.currentFPS * 1000) / 1000;
				}
				else {
					framerateValue = Math.round(connectionObj[displayObj[i].connection].ns.currentFPS * 1000) / 1000;
				}
			}
			
			/*
			// get the framerate element
			var framerateMsg:Text = displayObj[i].window.getElementAt(displayObj[i].window.numElements - 1);
			framerateMsg.text = framerateValue + " fps";
			*/
			
			// count the freeze times
			if (framerateValue == 0) {
				displayObj[i].zeroFramerateCounter++;
			}
			else {
				displayObj[i].zeroFramerateCounter = 0;
			}
			
			// detect frozen video (always freeze within 45 seconds)
			if (displayObj[i].zeroFramerateCounter >= 15) {
				myDebug("video " + i + " is freezing : try to recover...");
				if (SEPARATE_VIDEO_STREAM) {
					connectionObj[displayObj[i].connection].ns2.pause();
					connectionObj[displayObj[i].connection].ns2.resume();
				}
				else {
					connectionObj[displayObj[i].connection].ns.pause();
					connectionObj[displayObj[i].connection].ns.resume();
				}
				displayObj[i].zeroFramerateCounter = 0;
			}
		}
	}
}
