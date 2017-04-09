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

import com.adobe.crypto.MD5;

import mx.collections.ArrayCollection;
import mx.events.CloseEvent;
import mx.managers.PopUpManager;

private var is_new:Boolean = false;
private var is_edit_mode:Boolean = false;
private var is_edit_action:Boolean = false;

private var inputBox:input_box = null;
private var author:String = null;
private var validkey_req:String = null;
private var is_initial_complete:Boolean = false;
private var is_security_accept:Boolean = false;
private var is_privacy_authen:Boolean = false;
private var is_return_from_server:Boolean = false;
private var is_admin_permission:Boolean = false;
private var is_validkey_authen:Boolean = false;
private var is_password_request:Boolean = true;
private var is_load_meta_data_complete:Boolean = false;
private var is_load_xml_data_complete:Boolean = false;	

private var meta_course_title:String;
private var meta_course_passwordmd5:String;
private var meta_course_viewpasswordmd5:String;
private var meta_course_validkey:String;
private var meta_course_fileConversionOutput:String;
[Bindable]
private var contentDesc:ArrayCollection = null;

private var maxInterval:int = 5;
private var tmpInterval:int = 0;
private var countInterval:int = 0;

private var urlServerSide:URLRequest;
private var serverSideScript:String = null;
private var serverAuthInterval:int = 0;

private var convOutput:String = "jpg"; 
private var file:FileReference;
private var request:URLRequest;
private var pgTimer:Timer = null;
private var image_files:ArrayCollection;
private var is_logging_in:Boolean = false;

private var slide_position:int = 0;

private var pgAlert:Alert;

private function networkConnect():void {
	countInterval++;
	// wait for populating
	if (StringUtil.trim(meetingServer) == "") {
		myDebug("networkConnect retry");
		if (countInterval > maxInterval) {
			clearInterval(tmpInterval);
			tmpInterval = 0;
			Alert.show(resourceManager.getString('meeting_messages', 'connect_warning'));
		}
	}
	else {
		myDebug("networkConnect ok");
		clearInterval(tmpInterval);
		tmpInterval = 0;
		
		NetConnection.defaultObjectEncoding = flash.net.ObjectEncoding.AMF0;
		nc = new FMSConnection();
		nc.addEventListener( "success", connectionSuccessed );
		nc.addEventListener( "failed", connectionFailed );
		nc.addEventListener( "closed", connectionClosed);
		
		// 1st try
		connectRTMP();
		// 2nd try
		rtmpTimeOutID = setTimeout(connectRTMPT, 5000);
	}
}

private function waitAuthenAtServer():void {
	myDebug("waitAuthenAtServer");
	if (is_return_from_server && is_load_meta_data_complete) {
		if (is_edit_mode) {
			setContentData();
		}
		clearInterval(serverAuthInterval);
		serverAuthInterval = 0;
		
		myDebug("waitAuthenAtServer , " + is_validkey_authen);
		if (isPrivacyAuthen() && is_validkey_authen) {
			is_password_request = false;
			checkPassword();
		}
		else {
			Alert.show(resourceManager.getString('meeting_messages', 'access_warning'), null, Alert.OK, this, toMainPage);
		}
	}
}

private function checkPassword():void {
	myDebug("checkPassword");
	// remove busy cursor
	///CursorManager.removeBusyCursor();
	
	setExecuteButton();
	
	if (StringUtil.trim(meta_course_passwordmd5) != "" && !is_admin_permission && !is_edit_action) {
		editorPanel.enabled = false;
		
		inputBox = input_box(PopUpManager.createPopUp(this, input_box, true));
		inputBox.initData(resourceManager.getString('meeting_messages', 'password_box_title'), resourceManager.getString('meeting_messages', 'password_box_message'), true);
		inputBox["databox"].addEventListener(KeyboardEvent.KEY_UP, getPasswordBox);
		PopUpManager.centerPopUp(inputBox);
	}
	else {
		editorPanel.enabled = true;
	}
}

private function getPasswordBox(event:KeyboardEvent):void {
	// Enter or ESC
	if (event.keyCode == 13 ) {
		if (StringUtil.trim(meta_course_passwordmd5) == MD5.hash(StringUtil.trim(inputBox.databox.text))) {
			editorPanel.enabled = true;
		}
		else {
			Alert.show(resourceManager.getString('meeting_messages', 'password_box_incorrect'), null, Alert.OK, this, toMainPage);
		}
		PopUpManager.removePopUp(inputBox);
		inputBox = null;
	}
	else if (event.keyCode == 27) {
		PopUpManager.removePopUp(inputBox);
		inputBox = null;
	}
}

private function checkCourseAuthen(author:String): void {
	myDebug("checkCourseAuthen");
	nc.call("isCourseAuthen", new Responder(setCourseAuthen), contentID, author);
	myDebug("NC.call : isCourseAuthen");
}

private function setCourseAuthen(isauthen:Boolean): void {
	myDebug("NC.responder : isCourseAuthen");
	is_return_from_server = true;
	is_privacy_authen = isauthen;
}

private function isPrivacyAuthen():Boolean {
	myDebug("isPrivacyAuthen : " + (is_privacy_authen || is_admin_permission));
	return (is_privacy_authen || is_admin_permission);
}

private function loadMetaData(): void {
	// fixed always read data from cache
	var loader:URLLoader = new URLLoader();
	var header:URLRequestHeader = new URLRequestHeader("pragma", "no-cache");
	var url:URLRequest = new URLRequest(contentID + "/meta_description.xml");					
	url.requestHeaders.push(header);
	url.method = URLRequestMethod.GET;
	url.data = new URLVariables("time="+Number(new Date().getTime()));
	loader.addEventListener(Event.COMPLETE, retrieveMetaData);
	loader.load(url);
}

private function retrieveMetaData(event:Event): void {
	myDebug("retrieveMetaData");
	var i:int = 0;
	var xml:XML = new XML(event.target.data);
	
	meta_course_title = xml.title[0];
	meta_course_passwordmd5 = xml.passwordmd5[0];
	meta_course_viewpasswordmd5 = xml.viewpasswordmd5[0];
	meta_course_validkey = xml.validkey[0];
	meta_course_fileConversionOutput = ((xml.fileConversionOutput[0] == null) || (xml.fileConversionOutput[0].length() == 0)) ? "jpg" : xml.fileConversionOutput[0];
	is_load_meta_data_complete = true;
}

private function loadContentData():void {
	myDebug("loadContentData , " + contentID + "/original/content_description.xml");
	
	// fixed always read data from cache
	var loader:URLLoader = new URLLoader();
	var header:URLRequestHeader = new URLRequestHeader("pragma", "no-cache");
	var url:URLRequest = new URLRequest(contentID + "/original/content_description.xml");					
	url.requestHeaders.push(header);
	url.method = URLRequestMethod.GET;
	url.data = new URLVariables("time="+Number(new Date().getTime()));
	loader.addEventListener(Event.COMPLETE, retrieveContentData);
	loader.load(url);
}

private function retrieveContentData(event:Event): void {
	myDebug("retrieveContentData");
	
	var xml:XML = new XML(event.target.data);
	
	var i:int;
	var slide_list_data:ArrayCollection;
	var slide_title :String; // Title of slide
	var img_src:String; // Link of slide image
	var image:String; // Link of slide image
	var thumb:String; // Link of thumb image
	var preview:String; // Link of preview image 
	var slide_info :String; // Description of slide
	var slide_type:String; //Type of media (image, vector, video)
	
	// get slides data
	slide_list_data = new ArrayCollection();
	for(i = 0; i < xml.slides.slide.length();i++ ) {
		slide_type = ((xml.slides.slide[i].attribute("type") == null) || (xml.slides.slide[i].attribute("type").length() == 0)) ? "image" : xml.slides.slide[i].attribute("type");
		img_src = xml.slides.slide[i];
		if (slide_type.toLowerCase() == "video") {
			image = contentID + "/original/" + img_src;
			thumb = contentID + "/original/flv/thumb/" + img_src;
			preview = image;
		}
		else {
			image = contentID + "/original/files/" + img_src;
			thumb = contentID + "/original/files/thumb/" + img_src;
			preview = contentID + "/original/files/preview/" + img_src;
		}
		slide_title = xml.slides.slide[i].attribute("title");
		slide_info = xml.slides.slide[i].attribute("info");
		slide_list_data.addItem({page:(i+1), title:slide_title, image:image, thumb:thumb, preview:preview, image_src:img_src, description:slide_info, type:slide_type});		
	}
	
	contentDesc = slide_list_data;
}

private function addNewPage(): Object {
	// generate file name
	var ctime:Number = new Date().getTime();
	var img_src:String = ctime + "-blank.png";
	
	// create file ate server
	nc.call("createBlankFile", null, contentID, img_src, true);
	myDebug("NC.call : createBlankFile");
	
	var image:String = contentID + "/original/files/" + img_src;
	var thumb:String = contentID + "/original/files/thumb/" + img_src;
	var newPage:Object = {page:0, title:"", image:image, thumb:image, image_src:img_src, description:""};
	
	return newPage;
}

private function connectionSuccessed( event:Event ):void {
	myDebug("connected to server using .. " + connected_protocol);
	clearTimeout(rtmpTimeOutID);
	rtmpTimeOutID = 0;
	
	// security and owner check for editing
	if (is_edit_mode) {
		checkCourseAuthen(author);
		editorPanel.enabled = false;
		loadMetaData();
		loadContentData();
		serverAuthInterval = setInterval(waitAuthenAtServer, 100);
	}
	else {
		editorPanel.enabled = true;
	}
	
	serverSideScript = "http://" + meetingServer + "/" + meeting_home + "/servlet/wbUploadFile?room=" + contentID + "&convOutput=" + meta_course_fileConversionOutput + "&orig=1";
}

private function selectFileStart(evt:Event): void {
	myDebug("selectFileStart");
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
	myDebug("selectFileEnd");
	request = new URLRequest;
	request.url = "http://" + meetingServer + "/" + meeting_home + "/servlet/wbUploadFile?room=" + contentID + "&convOutput=" + meta_course_fileConversionOutput + "&orig=1";
	file.upload(request, "filedata", false);
	CursorManager.setBusyCursor();
}

private function uploadEnd(evt:Event): void {
	myDebug("uploadEnd");
	
	pgTimer = new Timer(500);
	pgTimer.addEventListener(TimerEvent.TIMER, progressHandler);
	pgTimer.start();	
}

private function uploadError(evt:Event): void {
	myDebug("uploadError");
	Alert.show("Error");
	CursorManager.removeBusyCursor();
}

private function progressHandler(event:TimerEvent) : void {
	nc.call("isConvertComplete", new Responder(executeResult), contentID);
	myDebug("NC.call : isConvertComplete");
}

private function executeResult(status:Boolean):void {
	myDebug("NC.responder : isConvertComplete");

	if (status) {
		// keep existing edited data
		if (is_edit_mode) {
			myDebug("keep existing edited data");
			for (var i:int = 0; i < contentDesc.length; i++) {
				var page:int = contentDesc.getItemAt(i).page;
				var title:String = contentDesc.getItemAt(i).title;
				var image:String = contentDesc.getItemAt(i).image_src;
				var description:String = contentDesc.getItemAt(i).description;
				myDebug("slide_position : " + slide_position);
				
				nc.call("setEditorData", null, ((i == 0) ? true : false), page, title, image, description);
				myDebug("NC.call : setEditorData");
				
				//insert new file after the selected slide position
				if(i == slide_position) {  
					nc.call("insertEditorData", null, contentID, is_edit_mode, true);
					myDebug("NC.call : insertEditorData");
					myDebug("insert_slide_position : " + slide_position);
				} 
			}
		}
		// generate the content template
		nc.call("genEditorTemplate", null, contentID, is_edit_mode, true, is_new);
		myDebug("NC.call : genEditorTemplate");
		
		pgTimer.stop();
		
	//	clearStatusInfo();
	
		// automatic close alert box
		PopUpManager.removePopUp(pgAlert);
		Alert.show(resourceManager.getString('meeting_messages', 'save_complete'), null, Alert.OK, this, toEditPage);
		
	}
}

private function reloadContent (eventObj:CloseEvent = null):void {
	
	loadContentData();
	setContentData();
	
}

private function toEditPage(eventObj:CloseEvent):void {
	// Check to see if the OK button was pressed.
	if (eventObj.detail == Alert.OK) {
		/*** [flasharea] is the name of display frame in the web ***/
		navigateToURL(new URLRequest('content_editor.html?id=' + contentID + '&author=' + author + '&security=accept&mode=edit&new=' + (is_new ? "1" : "0") + '&lang=' + lang), 'flasharea');
	}
}

// dummy functions
private function connectionFailed(event:Event):void {
	
}

private function connectionClosed(evtChange:Event):void {
	
}

private function reConnection():void {
	
}

private function networkBWHandler(netBW:Number):void {
	
}


	
