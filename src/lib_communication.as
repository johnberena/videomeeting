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

// connection
[Bindable]
private var nc:FMSConnection;
private var rtmpTimeOutID:uint;//For setTimeout
private var connected_protocol:String;

// virtual room information
private var mainPanel:Panel = null;
private var meetingServer:String = null;
private var meetingServerPort:String = null;
private var initContentID:String = null;
private var contentID:String = null;
private var userClass:String = null;
private var roomNumber:String = null;
private var roomTitle:String = null;
private var clientID:Number;
private var loginTime:String = null;
private var meeting_home:String = "/Meeting";
private var meeting_data_path:String = "/var/WebELS/Meeting/tomcat/WebELSx/data";

// content view password verification (for chairman function)
private var viewPassword:String = null;
public var verifyViewPassword:verify_password = null;

// shared object for sending video meeting and presentation signals
private var so_meeting:SharedObject;
// shared object for sending signals used in lecture mode, specifically chat messaging and sync of embedded video 
private var so_lecture:SharedObject;

// network speed testing
private var tsFileName:String;
private var tsFileSize:Number;
private var tsDownloader:URLLoader;
private var tsStartTime:Number;

// reconnection settings
private static var MAX_RECONNECTION_TIME:int = 3; //For reconnecting count
private var reconnectTimeID:uint;//For setInterval (Re-Connection)
private var reconnectCount:int = 0; //For reconnecting count
private var is_auto_reconnection:Boolean = false;

private function common_init():void {
	//DEBUG = true;
	
	// get from params
	lang = (getUrlParamateres("lang") == null) ? lang : getUrlParamateres("lang");
	resourceManager.loadResourceModule("meeting_messages_" + lang + ".swf");
	resourceManager.localeChain = [ lang ];
	myDebug("lang = " + lang);
	
	// get content id
	initContentID = (getUrlParamateres("id") == null) ? "0" : getUrlParamateres("id"); 
	contentID = initContentID;
	myDebug("contentID = " + contentID);
	
	// get user class  ; 1 = member , 0 = guest
	userClass = (getUrlParamateres("user") == null) ? "1" : getUrlParamateres("user"); 
	myDebug("userClass = " + userClass);
	
	var url:URLRequest = new URLRequest("videomeeting.xml");
	var loader:URLLoader = new URLLoader();
	loader.addEventListener(Event.COMPLETE, getServerInfo);
	loader.load(url);
	
	url = new URLRequest(contentID + "/virtualroom.xml");
	loader = new URLLoader();
	loader.addEventListener(Event.COMPLETE, getMeetingInfo);
	loader.load(url);
}

private function getServerInfo(event:Event):void {
	var xml:XML = new XML(event.target.data);
	meetingServer = xml.server[0];
	meetingServerPort = xml.port[0];
	meeting_home = (xml.meetinghome[0] == null) ? meeting_home : xml.meetinghome[0];
	meeting_data_path = (xml.datapath[0] == null) ? meeting_data_path : xml.datapath[0]; 
	SEPARATE_VIDEO_STREAM = checkBoolean(xml.separatedvideo[0]);
	PRE_DOWNLOAD_SLIDE = checkBoolean(xml.predownloadslide[0]);
	H264_VIDEO_CODEC = checkBoolean(xml.h264codec[0]);
	H264_PROFILE = xml.h264profile[0];
	H264_LEVEL = xml.h264level[0];
	SEND_BUFFER_TIME = xml.sendbuffertime[0];
	RECV_BUFFER_TIME = xml.recvbuffertime[0];
	ENABLE_LECTURE_CLIENT = checkBoolean(xml.enablelectureclient[0]);
	SIP_ENABLED = checkBoolean(xml.enableSIP[0]);
	DEBUG = checkBoolean(xml.debug[0]);
	
	myDebug("getServerInfo : " + meetingServer + ", port : " + meetingServerPort);
	myDebug("separatedvideo = " + SEPARATE_VIDEO_STREAM );
	myDebug("predownloadslide = " + PRE_DOWNLOAD_SLIDE);
	myDebug("h264codec = " + H264_VIDEO_CODEC + "; h264profile = " + H264_PROFILE + "; h264level = " + H264_LEVEL );
	myDebug("send_buffer_time = " + SEND_BUFFER_TIME + "; recv_buffer_time = " + RECV_BUFFER_TIME);
	myDebug("enable_lecture_client = " + ENABLE_LECTURE_CLIENT);
	myDebug("enable_SIP = " + SIP_ENABLED);
	myDebug("debug = " + DEBUG);
}

private function getMeetingInfo(event:Event):void {
	var xml:XML = new XML(event.target.data);
	roomNumber = xml.room[0];
	roomTitle = xml.title[0];
	myDebug("getMeetingInfo : " + roomNumber + ":" + roomTitle);
	
	mainPanel.title = roomTitle;
	mainPanel.enabled = true;
	
}

private function getUrlParamateres(paramKey:String):String {
	var paramValue:String = null;
	var fullUrl:String = "";
	if (!APPMODE) {
		fullUrl = ExternalInterface.call('eval','document.location.href');
	}
	var paramStr:String = fullUrl.split('?')[1];
	if (paramStr != null) {
		var params:Array = paramStr.split('&');
		for (var i:int = 0; i < params.length; i++) {
			var kv:Array = params[i].split('=');
			if (StringUtil.trim(kv[0]) == StringUtil.trim(paramKey)) {
				paramValue = StringUtil.trim(kv[1].split('#')[0]);
			}
		}
	} 
	return paramValue;
}

private function toMainPage(eventObj:CloseEvent):void {
	// Check to see if the OK button was pressed.
	if (eventObj.detail == Alert.OK) {
		navigateToURL(new URLRequest(meeting_home + '/'),'_top');
	}
}

private function initAutoReconnecting():void {
	// for auto reconnection
	reconnectTimeID = 0;
	reconnectCount = 0;
	is_auto_reconnection = false;
}

private function autoReconnecting():void {
	myDebug("reconnecting....");
	
	if (reconnectCount < MAX_RECONNECTION_TIME) {
		reConnection();
	}
	else {
		NotificatorManager.show(resourceManager.getString('meeting_messages', 'max_reconnect_warning'), NotificatorMode.WARNING, noticsDuration);
		clearInterval(reconnectTimeID);
		reconnectTimeID = 0;
	}
	reconnectCount++;
}

private function connectRTMP():void {
	myDebug("*** trying to connect with RTMP *** ");
	connected_protocol = "RTMP";
	if (meetingServerPort != "") {
		nc.connect("rtmp://" + meetingServer + ":" + meetingServerPort + "/" + roomNumber);
	}
	else {
		nc.connect("rtmp://" + meetingServer + "/" + roomNumber);
	}
}

//-------------Switch to RTMPT when RTMP cannot use-----------------------------//
private function connectRTMPT():void {
	myDebug("*** trying to connect with RTMPT *** ");
	connected_protocol = "RTMPT";
	if(!nc.connected){
		nc.connect("rtmpt://" + meetingServer + "/" + roomNumber);
	}
}

private function onSecurityError(evt:SecurityErrorEvent):void {
	trace("Security Error");
}

// test the speed of network
// http://www.munkiihouse.com/?p=28
// http://www.munkiihouse.com/?p=41
private function tsInit(): void {
	tsFileName = "http://" + meetingServer + "/" + meeting_home + "/WebELSMeeting.png";
	//myDebug("tsFileName = " + tsFileName);
	
	tsDownloader = new URLLoader();
	tsDownloader.addEventListener(Event.COMPLETE, tsComplete);			
	tsDownloader.addEventListener(IOErrorEvent.IO_ERROR, tsError);
	tsDownloader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, tsError);
	tsDownloader.addEventListener(ProgressEvent.PROGRESS, tsProgress);
	
	tsRun();
}

private function tsRun():void {
	var request:URLRequest = new URLRequest( tsFileName + "?rand="+Math.random() ); // avoid hitting cache
	tsStartTime = ( new Date() ).time;
	tsDownloader.load( request );
}

/**
 * Download successful
 * Return average download speed
 */
private function tsComplete(e:Event):void {
	var _finishTime:Number = ( new Date() ).time;
	var _totalTime:Number = ( _finishTime - tsStartTime ) / 1000; // total seconds
	var tsBandwidth:Number = tsFileSize / _totalTime;
	tsBandwidth = tsBandwidth * 8;	// convert Byte -> Bit
	
	myDebug("testing bandwidth = " + parseInt(tsBandwidth.toString()) + " Bit");
	
	networkBWHandler(tsBandwidth);
}

/**
 * Download failed
 * Return error
 */
private function tsError(e:Event):void {
	trace(e.toString());
}

private function tsProgress(e:ProgressEvent):void {
	tsFileSize = e.bytesTotal / 1024; // KB
}

