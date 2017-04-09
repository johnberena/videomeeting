
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

//chairman's function
private var is_chairman:Boolean = false;  //20120619
private var is_chairman_exist:Boolean = false; // 20140714
private var newRoomID:String = null;
private var is_password_verified:Boolean = false;
private var sort_order:String = "lastmodified"; // sort options: 1-lastmodified ; 2-title

//private var contentTitle:String = null;

private function isChairman(clientid:int):Boolean {
	myWbDebug("isChairman");
	var is_chairman:Boolean = false;
	for(var i:int = 0; i < meetingUsers.length;i++) {
		if(meetingUsers[i].clientid == clientid && meetingUsers[i].chairman) {
			is_chairman = true;
			is_chairman_exist = true; // 20140714
			break;
		}
	}
	return is_chairman;
}

private function chairman_change(evt:Event):void {
	if (wb_box.chairman.selected) {
		NotificatorManager.show(resourceManager.getString('meeting_messages', 'is_chairman'), NotificatorMode.WARNING, noticsDuration);
		// get the latest content list
		nc.call("getContentsList", new Responder(contentsListResult), contentID, sort_order); //get existing contents/presentation list
		myDebug("NC.call : getContentsList");
		is_chairman = true;
		
		// set chairman at server
		nc.call("setChairman", null, true);
		myDebug("NC.call : setChairman");
		
		//content_tool.enabled = true;
	}
	else {
		if (contentID != initContentID) {
			is_password_verified = true;
			changeContent(initContentID);
		}
		is_chairman = false;
		
		// remove chairman setting at server
		nc.call("setChairman", null, false);
		myDebug("NC.call : setChairman");
		
		//content_tool.enabled = false;
	}
	
	so_meeting.send("updateUserListStatus", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
	myDebug("SO.send : updateUserListStatus");
	// local update
	updateWbButtons();
}

private function sortOption(event:Event):void {
	var radioButton:RadioButton = event.target as RadioButton;
	switch (radioButton.id){
		case wb_box.sort_date.id:
			sort_order = "lastmodified";
			nc.call("getContentsList", new Responder(contentsListResult), contentID, sort_order); 
			break;
		case wb_box.sort_title.id:
			sort_order = "title";
			nc.call("getContentsList", new Responder(contentsListResult), contentID, sort_order); 
			break;
	}	
}

private function checkChairman():void {
	myWbDebug("checkChairman");
	
	if (userClass == "0") {
		return;
	}
	
	wb_box.chairman.enabled = true;
	for(var i:int = 0; i < meetingUsers.length;i++) {
		if(meetingUsers[i].chairman) {
			myWbDebug("checkChairman : found chairman id " + meetingUsers[i].clientid);
			if(meetingUsers[i].clientid != clientID) {
				wb_box.chairman.enabled = false;
				is_chairman_exist = true; // 20140714
			}
			break;
		} else {
			is_chairman_exist = false; // 20140714
		}
	}
}

private function changeContentList(event:ListEvent):void {
	myDebug("NC.responder : getContentsList");
	if (!is_offline_mode) { 
		myWbDebug("changeContentList");
		
		newRoomID = event.currentTarget.selectedItem.id;
		roomTitle = event.currentTarget.selectedItem.title;
		myWbDebug("changeContentList : id -" + newRoomID + " roomTitle - " + roomTitle);
		
		checkContentPassword(newRoomID);
		//changeContent(newRoomID);
	}
}

private function checkContentPassword(newRoomID:String):void {
	myDebug("checkContentPassword");
	
	var url:URLRequest = new URLRequest("http://" + meetingServer + "/" + meeting_home + "/data/course" + newRoomID + "A.xml?date=" + new Date().valueOf());
	var loader:URLLoader = new URLLoader();
	myDebug("checkContentPassword = " + url);
	loader.addEventListener(Event.COMPLETE, verifyPassword);
	loader.load(url);
}

private function verifyPassword(event:Event):void {
	myDebug("verifyPassword");
	var loader:URLLoader = URLLoader(event.target);
	var xml:XML = new XML(loader.data);
	viewPassword = xml.p.module[0].attribute("password");
	myDebug("verifyPassword = " + viewPassword);
	
	if (viewPassword != ""){
		verifyViewPassword = PopUpManager.createPopUp(this, verify_password, true) as verify_password;
		verifyViewPassword.init(viewPassword);
		verifyViewPassword.addEventListener("passwordVerification", changeContentDispatcher);
		PopUpManager.centerPopUp(verifyViewPassword);
	} else {
		is_password_verified = true;
		changeContent(newRoomID);
	}
}

private function changeContentDispatcher(event:Event): void{
	myDebug("changeContentDispatcher = " + newRoomID);
	is_password_verified = true;
	changeContent(newRoomID);
}

public function changeContent(newRoomID:String):void {
	if (!is_offline_mode) { 
				
		if (!is_password_verified) {
			return;
		}
		
		myWbDebug("changeContent, new content_id : " + newRoomID);
		savePageContent();
		wait(100);
				
		nc.call('changeContentID', null, newRoomID, roomNumber); // change the current content and initial new data on server
		myWbDebug("NC.call : changeContentID : newRoomID = " + newRoomID + ", roomNumber = " + roomNumber);
		
		present_page_num = 1; // set to the first page
		old_page_num = 1;
		
		//so_meeting.send("loadContentData", newRoomID);
		so_meeting.send("loadContentData", null);
		myWbDebug("SO.send : loadContentData");
		so_meeting.send("setSlideNumber", present_page_num, old_page_num, true);
		myWbDebug("SO.send : setSlideNumber");
		so_meeting.send("setContentTitle", roomTitle);
		myWbDebug("SO.send : setContentTitle");
		
		if(isA4Zoom){
			isA4Zoom = false;
			processZoomFit();
		}
		
		// update lecture client for content change
		if (ENABLE_LECTURE_CLIENT) {
			//so_lecture.send("loadContentData", newRoomID);
			so_lecture.send("loadContentData", null);
			myDebug("SO_lecture.send : loadContentData");
		}
		is_password_verified = false;
	}
}

/**
 * Set Contents List 
 **/
private function  contentsListResult(contents:Array):void {
	// myWbDebug("contentsListResult : " + contents);
	contentsList.removeAll();
	for (var i:int=0; i<contents.length; i++) {
		var tmp:Array = new String(contents[i]).split("::");
		contentsList.addItem({title:StringUtil.trim(tmp[1]), id:StringUtil.trim(tmp[0])});
		// display an activated content title
		if (StringUtil.trim(tmp[0]) == StringUtil.trim(contentID)) {
			wb_box.contents_list_cmb.selectedIndex = i;
		}
	}
}
