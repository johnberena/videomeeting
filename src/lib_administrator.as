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

// administrator's function
private var is_admin:Boolean = false;
private var is_admin_kick:Boolean = false; //If true, system cannot be login-ed
private var is_admin_mute_mic:Boolean = false;
private var is_admin_block_cam:Boolean = false;
private var is_mainvideo:Boolean = false;  //for video main display
private var old_mainvideo_id:int = 0;
private var is_shared_display:Boolean = false; //for shared video display of all users - 20121212
private var main_video_index:int = -1; //for shared video display of all users -　//20130108
private var sharedVideoData:Array = new Array;

private function isAdmin(clientid:int):Boolean {
	//myDebug("isAdmin");
	var is_admin:Boolean = false;
	for(var i:int = 0; i < meetingUsers.length;i++) {
		if(meetingUsers[i].clientid == clientid && meetingUsers[i].admin) {
			is_admin = true;
			break;
		}
	}
	return is_admin;
}

/////////////// Administrator tasks //////////////////////// 
private function admin_change(evt:Event):void {
	if (admin.selected) {
		NotificatorManager.show(resourceManager.getString('meeting_messages', 'is_admin'), NotificatorMode.WARNING, noticsDuration);
		is_admin = true;
		adminControl.visible = true;
		adminControl.enabled = true;
		
		kickout.setStyle("icon", icon_kickout_on);
		kickout.toolTip = resourceManager.getString('meeting_messages', 'tooltip_kickout');
		micMuteUser.setStyle("icon", icon_mute_mic_on);
		micMuteUser.toolTip = resourceManager.getString('meeting_messages', 'tooltip_mute_mic');
		micMuteAllUser.setStyle("icon", icon_muteall_mic_on);
		micMuteAllUser.toolTip = resourceManager.getString('meeting_messages', 'tooltip_muteall_mic');
		camBlockUser.setStyle("icon", icon_block_cam_on);
		camBlockUser.toolTip = resourceManager.getString('meeting_messages', 'tooltip_block_cam');
		camBlockAllUser.setStyle("icon", icon_blockall_cam_on);
		camBlockAllUser.toolTip = resourceManager.getString('meeting_messages', 'tooltip_blockall_cam');
		
		if(SIP_ENABLED) {
			invite_SIP_H323.includeInLayout = true;
			invite_SIP_H323.visible = true;
		}
		
	}
	else {
		is_admin = false;
		adminControl.visible = false;
		adminControl.enabled = false;
		
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
		
		//20121212
		if(is_shared_display){
			sharedDisplay.selected = false;
			is_shared_display = false;
			//send release shared video data 
			so_meeting.send("doReleaseSharedVideoDisplay", clientID);
			myDebug("SO.send : doReleaseSharedVideoDisplay");
		}
	}
	
	so_meeting.send("updateUserListStatus", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
	myDebug("SO.send : updateUserListStatus");
}

private function checkAdmin():void {
	myDebug("checkAdmin");
	
	if (userClass == "0") {
		return;
	}
	
	admin.enabled = true;
	for(var i:int = 0; i < meetingUsers.length;i++) {
		if(meetingUsers[i].admin) {
			myDebug("checkAdmin : found admin id " + meetingUsers[i].clientid);
			if(meetingUsers[i].clientid != clientID) {
				admin.enabled = false;
			}
			break;
		}
	}
}

// Kick User
private function kickUser():void {
	var selectedRow:Object;
	var kickID:Number;
	if(userManagementPanel) {
		selectedRow = userManagementPanel.adminUsersList.selectedItem;
		kickID = selectedRow.clientid;
	} else {
		selectedRow = lstUsers.selectedItem;
		kickID = selectedRow.clientid;
	}
	if(clientID != kickID && is_admin){
		Alert.show(resourceManager.getString('meeting_messages', 'confirm_kickout'), "Kickout", 
			Alert.YES|Alert.NO, null, confirmKickUser, null, Alert.NO);
	}
}

private function confirmKickUser(event:CloseEvent):void {
	if(event.detail == Alert.YES) {
		var selectedRow;
		if(userManagementPanel) {
			selectedRow = userManagementPanel.adminUsersList.selectedItem;
		} else {
			selectedRow = lstUsers.selectedItem;
		}
		so_meeting.send("doKickUser", clientID, selectedRow.clientid);
		myDebug("SO.send : doKickUser");
	}
}

public function doKickUser(adminID:Number, kickID:Number):void {
	myDebug("SO.recv : doKickUser");
	if(clientID == kickID && clientID != adminID){
		is_auto_reconnection = false;
		meetingLogout();
		is_admin_kick = true;
		NotificatorManager.show(resourceManager.getString('meeting_messages', 'is_kickout'), NotificatorMode.WARNING, noticsDuration);
	}
}

// Mute User 
private function muteUser():void {
	myDebug("muteUser");
	var selectedRow:Object;
	var muteID:Number;
	if(userManagementPanel) {
		selectedRow = userManagementPanel.adminUsersList.selectedItem;
		muteID = selectedRow.clientid;
	} else {
		selectedRow = lstUsers.selectedItem;
		muteID = selectedRow.clientid;
	}
	if(clientID != muteID && is_admin){
		Alert.show(resourceManager.getString('meeting_messages', 'confirm_mute'), "Mute/Unmute", 
			Alert.YES|Alert.NO, null, confirmMuteUser, null, Alert.NO);
	}
}

private function confirmMuteUser(event:CloseEvent):void {
	if(event.detail == Alert.YES) {
		var selectedRow:Object;	
		if(userManagementPanel) {
			selectedRow = userManagementPanel.adminUsersList.selectedItem;
		} else {
			selectedRow = lstUsers.selectedItem;
		}
		so_meeting.send("doMuteUser", clientID, selectedRow.clientid);
		myDebug("SO.send : doMuteUser");
	}
}

public function doMuteUser(adminID:Number, muteID:Number):void {
	myDebug("SO.recv : doMuteUser");
	if(clientID == muteID && clientID != adminID){
		if (is_mic_on) {
			// toggle mute state
			if (is_admin_mute_mic) {
				is_admin_mute_mic = false;
				startMicrophone();
				NotificatorManager.show(resourceManager.getString('meeting_messages', 'is_unmute'), NotificatorMode.WARNING, noticsDuration);
			}
			else {
				is_admin_mute_mic = true;
				stopMicrophone();
				NotificatorManager.show(resourceManager.getString('meeting_messages', 'is_mute'), NotificatorMode.WARNING, noticsDuration);
			}
		}
		so_meeting.send("updateUserListStatus", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
		myDebug("SO.send : updateUserListStatus");
	}
}

private function muteAllUser():void {
	Alert.show(resourceManager.getString('meeting_messages', 'confirm_muteall'), "Mute All", 
		Alert.YES|Alert.NO, null, confirmMuteAllUser, null, Alert.NO);
}

private function confirmMuteAllUser(event:CloseEvent):void {
	if(event.detail == Alert.YES) {
		so_meeting.send("doMuteAllUser", clientID);
		myDebug("SO.send : doMuteAllUser");
	}
}

public function doMuteAllUser(adminID:Number):void {
	myDebug("SO.recv : doMuteAllUser");
	// Mute all microphone, except an administrator and a mainvideo
	if(!(clientID == adminID || isMainvideo(clientID) || isPresenter(clientID))){
		if (is_mic_on) {
			micToggleManagement();
			NotificatorManager.show(resourceManager.getString('meeting_messages', 'is_mute'), NotificatorMode.WARNING, noticsDuration);
		}
		so_meeting.send("updateUserListStatus", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
		myDebug("SO.send : updateUserListStatus");
	}
}

// Off User Camera 
private function blockUserCam():void {
	myDebug("blockUserCam");
	var selectedRow:Object;
	var blockID:Number;	
	if(userManagementPanel) {
		selectedRow = userManagementPanel.adminUsersList.selectedItem;
		blockID = selectedRow.clientid;
	} else {
		selectedRow = lstUsers.selectedItem;
		blockID = selectedRow.clientid;
	}
	if(clientID != blockID && is_admin){
		Alert.show(resourceManager.getString('meeting_messages', 'confirm_block'), "Block/Unblock Camera", 
			Alert.YES|Alert.NO, null, confirmBlockUserCam, null, Alert.NO);
	}
}

private function confirmBlockUserCam(event:CloseEvent):void {
	if(event.detail == Alert.YES) {
		var selectedRow:Object;
		if(userManagementPanel) {
			selectedRow = userManagementPanel.adminUsersList.selectedItem;
		} else {
			selectedRow = lstUsers.selectedItem;
		}
		so_meeting.send("doBlockUserCam", clientID, selectedRow.clientid);
		myDebug("SO.send : doBlockUserCam");
	}
}

public function doBlockUserCam(adminID:Number, blockID:Number):void {
	myDebug("SO.recv : doBlockUserCam");
	if(clientID == blockID && clientID != adminID){
		if (is_cam_on) {
			// toggle mute state
			if (is_admin_block_cam) {
				is_admin_block_cam = false;
				startCamera();
				NotificatorManager.show(resourceManager.getString('meeting_messages', 'is_unblock_cam'), NotificatorMode.WARNING, noticsDuration);
			}
			else {
				is_admin_block_cam = true;
				stopCamera();
				NotificatorManager.show(resourceManager.getString('meeting_messages', 'is_block_cam'), NotificatorMode.WARNING, noticsDuration);
			}
		}		
		so_meeting.send("updateUserListStatus", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
		myDebug("SO.send : updateUserListStatus");
	}
}

// Off All User Cameras 
private function blockAllUserCam():void {
	Alert.show(resourceManager.getString('meeting_messages', 'confirm_blockall'), "Turn off camera", 
		Alert.YES|Alert.NO, null, confirmBlockAllUserCam, null, Alert.NO);
}

private function confirmBlockAllUserCam(event:CloseEvent):void {
	if(event.detail == Alert.YES) {
		so_meeting.send("doBlockAllUserCam", clientID);
		myDebug("SO.send : doBlockAllUserCam");
	}
}

public function doBlockAllUserCam(adminID:Number):void {
	myDebug("SO.recv : doBlockAllUserCam");
	// Turn off all cameras, except an administrator and a mainvideo
	if(!(clientID == adminID || isMainvideo(clientID) || isPresenter(clientID))){
		if (is_cam_on) {
			camToggleManagement();
			NotificatorManager.show(resourceManager.getString('meeting_messages', 'is_unblock_cam'), NotificatorMode.WARNING, noticsDuration);
		}		
		so_meeting.send("updateUserListStatus", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
		myDebug("SO.send : updateUserListStatus");
	}
}


private function isExistingMainvideo():Boolean {
	var found:Boolean = false;
	for(var i:int = 0; i < meetingUsers.length;i++) {
		if(meetingUsers[i].mainvideo) {
			myDebug("isExistingMainvideo : found mainvideo id " + meetingUsers[i].clientid);
			found = true;
			break;
		}
	}
	return found;
}

private function getMainvideoID():Number {
	var id:Number = 0;
	for(var i:int = 0; i < meetingUsers.length;i++) {
		if(meetingUsers[i].mainvideo) {
			myDebug("getMainvideoID : found mainvideo id " + meetingUsers[i].clientid);
			id = meetingUsers[i].clientid;
			break;
		}
	}
	return id;
}

private function checkMainvideo():void {
	myDebug("checkMainvideo");
	for(var i:int = 0; i < meetingUsers.length;i++) {
		if(meetingUsers[i].mainvideo) {
			myDebug("checkMainvideo : found mainvideo id " + meetingUsers[i].clientid);
			updateMainvideoView(true);
			break;
		}
	}
}

private function isMainvideo(clientid:int):Boolean {
	myDebug("isMainvideo");
	var is_mainvideo:Boolean = false;
	for(var i:int = 0; i < meetingUsers.length;i++) {
		if(meetingUsers[i].clientid == clientid && meetingUsers[i].mainvideo) {
			myDebug("isMainvideo : found mainvideo id " + meetingUsers[i].clientid);
			is_mainvideo = true;
			break;
		}
	}
	return is_mainvideo;
}

// set mainvideo 
private function setMainvideo():void {
	myDebug("setMainvideo");
	var selectedRow:Object;
	var mainvideoID:Number;
	if(userManagementPanel) {
		selectedRow = userManagementPanel.adminUsersList.selectedItem;
		mainvideoID = selectedRow.clientid;
	} else {
		selectedRow = lstUsers.selectedItem;
		mainvideoID = selectedRow.clientid;
	}
	if(is_admin){
		Alert.show(resourceManager.getString('meeting_messages', 'confirm_mainvideo'), "Set/Unset main video", 
			Alert.YES|Alert.NO, null, confirmSetMainvideo, null, Alert.NO);
	}
}

private function confirmSetMainvideo(event:CloseEvent):void {
	if(event.detail == Alert.YES) {
		var selectedRow:Object;
		if(userManagementPanel) {
			selectedRow = userManagementPanel.adminUsersList.selectedItem;
		} else {
			selectedRow = lstUsers.selectedItem;
		}
		so_meeting.send("doResetMainvideo", selectedRow.clientid);
		myDebug("SO.send : doResetMainvideo");
		so_meeting.send("doSetMainvideo", selectedRow.clientid);
		myDebug("SO.send : doUnsetMainvideo");
	}
}

public function doResetMainvideo(mainvideoID:Number):void {
	myDebug("SO.recv : doUnsetMainvideo");
	
	// get an old mainvideo
	old_mainvideo_id = getMainvideoID();
	
	var i:int;
	// clear mainvideo flag
	for(i = 0; i < meetingUsers.length;i++) {
		meetingUsers[i].mainvideo = false;
	}
	// reset window actions 
	for (i = 0; i < MAX_DISPLAYS; i++) {
		displayObj[i].window.doubleClickEnabled = true;
	}
}

public function doSetMainvideo(mainvideoID:Number):void {
	//myDebug("doSetMainvideo");
	if (mainvideoID == clientID) {
		myDebug("SO.recv : doSetMainvideo");
		if (old_mainvideo_id == mainvideoID) {
			is_mainvideo = !is_mainvideo;
		}
		else {
			is_mainvideo = true;
		}
		
		so_meeting.send("updateUserListStatus", loging_name, clientID, userClass, loginTime, is_cam_on, is_mic_on, is_admin, is_admin_mute_mic, is_admin_block_cam, is_mainvideo, is_presenter, is_chairman);
		myDebug("SO.send : updateUserListStatus");
		wait(100);
		so_meeting.send("updateMainvideoView", is_mainvideo);
		myDebug("SO.send : updateMainvideoView");
	}
}



// set shared video display by admin - 20121212
private function sharedDisplay_toggle(): void {
	myDebug("sharedDisplay_toggle - is_shared_display :" + is_shared_display);	
	
	if (is_admin) {    //for admin
		if (is_shared_display) {
			sharedVideoData = new Array;
			//Scan Display Object and populate sync display array
			for (var j:int = 0; j < MAX_DISPLAYS; j++) {
				if (displayObj[j].connected) {
					sharedVideoData[j] = connectionObj[displayObj[j].connection].client;
					//	myDebug("sharedVideoDisplay - " + connectionObj[displayObj[j].connection].client + ":" + displayObj[j].connected);	
				} else {
					sharedVideoData[j] = -1;
				}
			}
			
			//20130108 - set main video
			sharedVideoData[MAX_DISPLAYS] = main_video_index;
		
			myDebug("[send] shared video display data: " + sharedVideoData);
			
			//send shared video data array via shared object
			so_meeting.send("doSharedVideoDisplay", sharedVideoData, clientID); 
			myDebug("SO.send : doSharedVideoDisplay");
		} else {
			myDebug("Release sharedVideoDisplay");
			//send release shared video data 
			so_meeting.send("doReleaseSharedVideoDisplay", clientID);
			myDebug("SO.send : doReleaseSharedVideoDisplay");
		}
	}
}

// do shared video display - 20121212
public function doSharedVideoDisplay(data:Array, userID:int):void {
	if (userID != clientID) {  // not admin
		myDebug("SO.recv : doSharedVideoDisplay");
		myDebug("[receive] shared video display data: " + data);
		sharedVideoData = data;
		updateSharedVideoDisplay();
		
		//Disable change layout buttons - 20130509
		tgMainLayout.enabled = false;
		tgVideoLayout.enabled = false;
		tgWhiteboardLayout.enabled = false;
		tgBigVideoLayout.enabled = false;
		tgFullVideoLayout.enabled = false;
	}
}

// do shared video display - 20121212
private function updateSharedVideoDisplay():void {
	myDebug("updateSharedVideoDisplay");
	
	if (!is_shared_display) {
		NotificatorManager.show(resourceManager.getString('meeting_messages', 'video_sync_by_admin'), NotificatorMode.WARNING, noticsDuration);
	}
	is_shared_display = true; // enable shared display mode
	lstUsers.doubleClickEnabled = false;  // disable double click of user list
	if(userManagementPanel) {
		userManagementPanel.adminUsersList.doubleClickEnabled = false;
	}
	// close all openned videos
	for (var i:int = 0; i < MAX_DISPLAYS; i++) {
		if (displayObj[i].connected) {
			connectionObj[displayObj[i].connection].force_close_display = true;
			closeVideo(i);
		}
	}
	
	for (var j:int = 0; j < MAX_DISPLAYS; j++) {
		// confirm the openned video status
		if (sharedVideoData[j] != -1) {
			// open video from local camera
			if (sharedVideoData[j] == clientID && is_cam_on) {
				displayVideo(CONN_INDEX_SENDER, clientID, loging_name + " (" + resourceManager.getString('meeting_messages', 'label_host') + ")", true, myCam, null, j);
			}
				// open video from broadcasting stream
			else{
				// find the connection id from client id
				for (var k:int = 0; k < MAX_CONNECTIONS; k++) {
					if (connectionObj[k].client == sharedVideoData[j]) {  
						var uname:String = getClientName(connectionObj[k].client);
						displayVideo(k, sharedVideoData[j], uname, false, null, connectionObj[k].ns, j);
						break;
					}
				}
			}
		}
	}
	
	//20130108 - set main video
	if (sharedVideoData[MAX_DISPLAYS] != -1){
		enlargeDisplay(sharedVideoData[MAX_DISPLAYS]);
	}
}

// do release shared video display - 20121212
public function doReleaseSharedVideoDisplay(userID:int):void {
	myDebug("SO.recv : doReleaseSharedVideoDisplay");
	
	if (userID != clientID) {  // not admin
		is_shared_display = false;
		
		// show close button
		for (var i:int = 0; i < MAX_DISPLAYS; i++) {
			if (displayObj[i].connected) {
				displayObj[i].window.closeButton.visible = true;
				displayObj[i].window.doubleClickEnabled = true;
			}
		}
		lstUsers.doubleClickEnabled = true;  // enable doubleclick for userList
		userManagementPanel.adminUsersList.doubleClickEnabled = true;
		
		//Enable change layout - 20130509
		tgMainLayout.enabled = true;
		tgVideoLayout.enabled = true;
		tgWhiteboardLayout.enabled = true;
		tgBigVideoLayout.enabled = true;
		tgFullVideoLayout.enabled = true;
		
		NotificatorManager.show(resourceManager.getString('meeting_messages', 'video_sync_by_admin_released'), NotificatorMode.WARNING, noticsDuration);
	}
}

// do enlarge shared video display - 20130205
public function updateEnlargeSharedVideoDisplay(enlargeIdx:int, force_restore:Boolean, adminID:int):void {
	myDebug("SO.recv : updateEnlargeSharedVideoDisplay");
	if (adminID != clientID){
		enlargeDisplay(enlargeIdx, force_restore);
	}
}

