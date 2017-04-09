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

import com.rectius.library.notificator.NotificatorManager;
import com.rectius.library.notificator.NotificatorMode;
import com.renaun.samples.net.FMSConnection;

import flash.display.Shape;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.external.ExternalInterface;
import flash.geom.Matrix;
import flash.media.H264Level;
import flash.media.H264Profile;
import flash.media.H264VideoStreamSettings;
import flash.media.Microphone;
import flash.media.SoundMixer;
import flash.media.SoundTransform;
import flash.net.FileFilter;
import flash.net.FileReference;
import flash.net.FileReferenceList;
import flash.net.NetStream;
import flash.net.Responder;
import flash.net.SharedObject;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.utils.Timer;
import flash.utils.getTimer;

import mx.collections.ArrayCollection;
import mx.controls.Alert;
import mx.controls.Text;
import mx.core.EventPriority;
import mx.core.FlexGlobals;
import mx.events.CloseEvent;
import mx.events.FlexEvent;
import mx.events.ResizeEvent;
import mx.events.ListEvent;
import mx.events.SliderEvent;
import mx.managers.CursorManager;
import mx.managers.PopUpManager;
import mx.resources.ResourceBundle;
import mx.resources.ResourceManager;
import mx.utils.Base64Encoder;
import mx.utils.StringUtil;

import org.gif.player.GIFPlayer;

import spark.components.Panel;
import spark.components.VideoDisplay;
import spark.components.RadioButton;

[Embed(source="assets/webcamera-OFF-24x24.png")]
[Bindable] private var icon_cam_off:Class;
[Embed(source="assets/webcamera-ON-24x24.png")]
[Bindable] private var icon_cam_on:Class;
[Embed(source="assets/webcamera-NONE-24x24.png")]
[Bindable] private var icon_cam_none:Class;
[Embed(source="assets/microphone-OFF-24x24.png")]
[Bindable] private var icon_mic_off:Class;
[Embed(source="assets/microphone-ON-24x24.png")]
[Bindable] private var icon_mic_on:Class;
[Embed(source="assets/microphone-NONE-24x24.png")]
[Bindable] private var icon_mic_none:Class;
[Embed(source="assets/echotest-OFF-24x24.png")]
[Bindable] private var icon_echo_off:Class;
[Embed(source="assets/echotest-ON-24x24.png")]
[Bindable] private var icon_echo_on:Class;
[Embed(source="assets/speaker-OFF-24x24.png")]
[Bindable] private var icon_spkr_off:Class;
[Embed(source="assets/speaker-ON-24x24.png")]
[Bindable] private var icon_spkr_on:Class;
[Embed(source="assets/kickout-24x24.png")]
[Bindable] private var icon_kickout_on:Class;
[Embed(source="assets/kickout-DIS-24x24.png")]
[Bindable] private var icon_kickout_off:Class;
[Embed(source="assets/microphone-MUTE-24x24.png")]
[Bindable] private var icon_mute_mic_on:Class;
[Embed(source="assets/microphone-MUTE-DIS-24x24.png")]
[Bindable] private var icon_mute_mic_off:Class;
[Embed(source="assets/microphone-MUTEALL-24x24.png")]
[Bindable] private var icon_muteall_mic_on:Class;
[Embed(source="assets/microphone-MUTEALL-DIS-24x24.png")]
[Bindable] private var icon_muteall_mic_off:Class;
[Embed(source="assets/webcamera-BLOCK-24x24.png")]
[Bindable] private var icon_block_cam_on:Class;
[Embed(source="assets/webcamera-BLOCK-DIS-24x24.png")]
[Bindable] private var icon_block_cam_off:Class;
[Embed(source="assets/webcamera-BLOCKALL-24x24.png")]
[Bindable] private var icon_blockall_cam_on:Class;
[Embed(source="assets/webcamera-BLOCKALL-DIS-24x24.png")]
[Bindable] private var icon_blockall_cam_off:Class;
[Embed(source = 'assets/mainvideo-24x24.png')]
[Bindable] private var icon_main_video:Class;
[Embed(source="assets/sidedisplay-ON-24x24.png")]
[Bindable] private var icon_sidedisplay_on:Class;
[Embed(source = 'assets/sidedisplay-OFF-24x24.png')]
[Bindable] private var icon_sidedisplay_off:Class;
[Embed(source = 'assets/small-layout-24x24.png')]
[Bindable] private var icon_small_layout_switch:Class;
[Embed(source = 'assets/layout-vw.png')]
[Bindable] private var icon_layout_vw_switch:Class;
[Embed(source = 'assets/layout-v.png')]
[Bindable] private var icon_layout_v_switch:Class;
[Embed(source = 'assets/layout-w.png')]
[Bindable] private var icon_layout_w_switch:Class;
[Embed(source = 'assets/layout-b.png')]
[Bindable] private var icon_layout_b_switch:Class;
[Embed(source = 'assets/layout-fs.png')]
[Bindable] private var icon_layout_fs_switch:Class;
[Embed(source = 'assets/layout-fs.png')]
[Bindable] private var icon_layout_focus_switch:Class;
[Embed(source = 'assets/chat-24x24.png')]
[Bindable] private var icon_chat_floating_panel:Class;
[Embed(source = 'assets/video-freeze-recover.png')]
[Bindable] private var icon_video_freeze_recover:Class;


private var APPMODE:Boolean = false;
private var DEBUG:Boolean = true;

//Audio-Video Settings
private var SEPARATE_VIDEO_STREAM:Boolean = false;	// separate video and voice streams
private var PRE_DOWNLOAD_SLIDE:Boolean = false;	// pre-content downloading or by slide downloading
private var H264_VIDEO_CODEC:Boolean = false; //sets H.264 video encoder
private var H264_PROFILE:String = null; //sets H.264 profile
private var H264_LEVEL:String = null; //sets H.264 level
private var SEND_BUFFER_TIME:Number = 0.0; //sets publishing stream buffer time
private var RECV_BUFFER_TIME:Number = 0.0; //sets subscribing stream buffer time
private var ENABLE_LECTURE_CLIENT:Boolean = false; // support the lecture client application
private var SIP_ENABLED:Boolean = false; //sets SIP Support

private static var MODE_CURSOR:int = 1;	// cursor mode
private static var MODE_ANNOTATION:int = 2;	// annotation mode

// Notification
[Bindable]
private var lang:String = "en";

// global timer
private var globalTimer:Timer = null;
private var globalTimeCounter:Number = 0;

private var noticsTitle:String  = "Video Meeting";
private var noticsDuration:int = 3000;
private var noticsPosition:String = "center";
private var noticsStack:Boolean = true;	


private function wait(len:int):void {
	var st:uint = getTimer();
	var time:uint;
	var tmp:uint = 0;
	while((time = (getTimer() - st)) <= len){
		/*
		if((time % 1000 == 0) && (tmp != time)){
		trace(tmp = time);
		}
		*/
	}
}

private function myDebug(dbgMsg:String):void {
	if (DEBUG) {
		if (APPMODE) {
			trace(dbgMsg);
		}
		else {
			ExternalInterface.call("console.log", "--DEBUG-- " + dbgMsg);
		}
	}
}

private function checkBoolean(value:String):Boolean {
	switch(value.toLowerCase()) {
		case "1":
		case "true":
		case "yes":
			return true;
		default:
			return false;
	}
}

