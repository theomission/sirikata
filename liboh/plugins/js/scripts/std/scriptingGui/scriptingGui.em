
system.require('std/core/simpleInput.em');

(function()
 {

     /**
      @param {std.ScriptingGui.Controller}
      
      @param {object: <String(visibleId):visible object>} nearbyVisMap
      -- all the visible objects that satisfy scripter's proximity
      query.

      @param {object: <String(visibleId):
      std.FileManager.FileManagerElement> scriptedVisMap -- A record
      of all visibles that we have scripted at some point.

      @param {object: <int:std.ScriptingGui.Action> actionMap -- Which
      actions are selectable by scripter.

      @param {std.ScriptingGui.Console} console -- has several
      scripting events.
      */
     std.ScriptingGui =
         function(controller,nearbyVisMap,scriptedVisMap,actionMap,console)
     {
         if (typeof(simulator) == 'undefined')
         {
             throw new Error('Cannot initialize scripting gui without ' +
                             'simulator graphics.');                 
         }


         this.controller       = controller;
         this.nearbyVisMap     = nearbyVisMap;
         this.scriptedVisMap   = scriptedVisMap;
         this.actionMap        = actionMap;
         this.console          = console;
         this.console.setScriptingGui(this);
         
         this.nameMap          ={};
         this.nameMap[system.self.toString()] = 'self';

         
         this.guiMod = simulator._simulator.addGUITextModule(
             guiName(),
             getGuiText(),
             std.core.bind(guiInitFunc,undefined,this));
         this.hasInited = false;
     };

     system.require('scriptingGuiUtil.em');
     
     std.ScriptingGui.prototype.redraw = function()
     {
         if (!this.hasInited)
             return;
         
         //trigger redraw call
         this.guiMod.call(
             'ishmaelRedraw',toHtmlNearbyMap(this),toHtmlScriptedMap(this),
             toHtmlActionMap(this),toHtmlFileMap(this),toHtmlNameMap(this),
             toHtmlConsoleMap(this));
     };

     
     /**
      @param {String} visId -- Id of visible.
      */
     //called by html to add the visible with id 
     std.ScriptingGui.prototype.hAddVisible = function(visId)
     {
         //already can script the visible.
         if (visId in this.scriptedVisMap)
         {
             this.console.guiEvent();
             this.redraw();
             return;
         }


         if (!(visId in this.nearbyVisMap))
         {
             //visible is no longer available.
             this.console.guiEvent();
             this.redraw();
             return;
         }

         //redraw called from inside of addVisible.
         this.controller.addVisible(this.nearbyVisMap[visId]);
     };

     std.ScriptingGui.prototype.hRemoveVisible = function(visId)
     {
         //FIXME: should finish this call
         throw new Error('FIXME: must finish hRemoveVisible call ' +
                         'in scriptingGui');
     };

     std.ScriptingGui.prototype.hRenameVisible = function (visId,visName)
     {
         var userQuery =
             'Enter new name for visible previously named ' + visName +
             ' and with id: ' + visId;
         
         var newInput = std.core.SimpleInput(
             std.core.SimpleInput.ENTER_TEXT,
             userQuery,
             std.core.bind(renameVisibleInputCB,undefined,this,visId));
     };


     function renameVisibleInputCB(scriptingGui,visId,newName)
     {
         scriptingGui.nameMap[visId] = newName;
         scriptingGui.redraw();
     }
         
     
     /**
      @param {String?} actId -- Should be parsedInt to get an index
      into actionMap
      @param {String} newText -- What action with actId should set as
      its text.
      */
     std.ScriptingGui.prototype.hSaveAction = function(actId,newText)
     {
         this.controller.editAction(parseInt(actId),newText);
     };

     /**
      @param {String?} actId -- Should be parsedInt to get an index
      into actionMap
      @param {String} newText -- What action with actId should set as
      its text.
      @param {String} visId   -- Id of visible to execute action on.
      */
     std.ScriptingGui.prototype.hSaveAndExecuteAction =
         function(actId,newText, visId)
     {
         this.hSaveAction(actId,newText);
         this.controller.execAction(actId,visId);
     };

     /**
      Prompt user for the name of the new action using
      std.core.SimpleInput.
      */
     std.ScriptingGui.prototype.hNewAction =
         function()
     {
         var newInput = std.core.SimpleInput(
             std.core.SimpleInput.ENTER_TEXT,
             'Enter new action\'s name',
             std.core.bind(addActionInputCB,undefined,this));
     };

     /**
      @param {std.ScriptingGui} scriptingGui
      @param {String} userResp_actionName - The name of the new action
      that the user wants.
      */
     function addActionInputCB(scriptingGui,userResp_actionName)
     {
         //new action won't have any text in it.
         scriptingGui.controller.addAction(userResp_actionName,'');
         scriptingGui.redraw();
     }

     /**
      @param {String?} actId -- Should be parsedInt to get an index
      into actionMap
      */
     std.ScriptingGui.prototype.hRemoveAction =
         function(actId)
     {
         this.controller.removeAction(parseInt(actId));
         this.redraw();
     };
     

     std.ScriptingGui.prototype.hAddFile =
         function(visId)
     {
         var newInput = std.core.SimpleInput(
             std.core.SimpleInput.ENTER_TEXT,
             'Enter new file\'s name',
             std.core.bind(addFileInputCB,undefined,this,visId));
     };

     
     function addFileInputCB(scriptingGui,visId,userResp_filename)
     {
         scriptingGui.controller.addExistingFileIfCan(
             visId,userResp_filename);
         scriptingGui.redraw();
     }


     //reread file first, then send it to visible.
     std.ScriptingGui.prototype.hUpdateAndSendFile =
         function(visId,filename)
     {
         this.controller.rereadFile(visId,filename);
         this.controller.updateFile(visId,filename);
     };

     std.ScriptingGui.prototype.hUpdateAndSendAllFiles =
         function(visId)
     {
         this.controller.rereadAllFiles(visId);
         this.controller.updateAll(visId);
     };


     std.ScriptingGui.prototype.hRemoveFile =
         function(visId,filename)
     {
         this.controller.removeFile(visId,filename);
         this.redraw();
     };

     
     /**
      @param {std.ScriptingGui} 
      */
     function guiInitFunc(scriptingGui)
     {
         scriptingGui.hasInited = true;
         
         //when a user clicks on any of the nearby visibles to script
         //them, want that object to move into scripted objects.  
         scriptingGui.guiMod.bind(
             'addVisible',
             std.core.bind(scriptingGui.hAddVisible,scriptingGui));

         //when a user clicks to remove any of the scripted visibles
         //from scripted map, then destroy it.
         scriptingGui.guiMod.bind(
             'removeVisible',
             std.core.bind(scriptingGui.hRemoveVisible,scriptingGui));

         scriptingGui.guiMod.bind(
             'renameVisible',
             std.core.bind(scriptingGui.hRenameVisible,scriptingGui));
         
         //when a user updates a particular action, and clicks to save
         //the new action text.
         scriptingGui.guiMod.bind(
             'saveAction',
             std.core.bind(scriptingGui.hSaveAction,scriptingGui));


         //saves and executes action to visible.
         scriptingGui.guiMod.bind(
             'saveAndExecuteAction',
             std.core.bind(scriptingGui.hSaveAndExecuteAction,scriptingGui));


         scriptingGui.guiMod.bind(
             'newAction',
             std.core.bind(scriptingGui.hNewAction,scriptingGui));

         scriptingGui.guiMod.bind(
             'removeAction',
             std.core.bind(scriptingGui.hRemoveAction,scriptingGui));

         scriptingGui.guiMod.bind(
             'addFile',
             std.core.bind(scriptingGui.hAddFile,scriptingGui));

         scriptingGui.guiMod.bind(
             'updateAndSendFile',
             std.core.bind(scriptingGui.hUpdateAndSendFile,scriptingGui));

         scriptingGui.guiMod.bind(
             'updateAndSendAllFiles',
             std.core.bind(scriptingGui.hUpdateAndSendAllFiles,scriptingGui));

         scriptingGui.guiMod.bind(
             'removeFile',
             std.core.bind(scriptingGui.hRemoveFile,scriptingGui));
         
         
         scriptingGui.redraw();
     }
     
     /**
      @returns {object: <string (visibleId): string (visibleId)>}
      scriptingGui -- Takes the list of nearby objects and turns it
      into an object that (for now) maps visibleIds to visibleIds.

      @see ishmaelRedraw
      */
     function toHtmlNearbyMap(scriptingGui)
     {
         var returner = { };
         for (var s in scriptingGui.nearbyVisMap)
             returner[s] = s;
         return returner;
     }


     /**
      @returns {object: <string (visibleId): string (visibleId)>}
      scriptingGui -- Takes the list of nearby objects and turns it
      into an object that (for now) maps visibleIds to visibleIds.

      @see ishmaelRedraw
      */
     function toHtmlScriptedMap(scriptingGui)
     {
         var returner = { };
         for (var s in scriptingGui.scriptedVisMap)
             returner[s] = s;
         return returner;
     }


     function toHtmlActionMap(scriptingGui)
     {
         return scriptingGui.actionMap;
     }


     function toHtmlFileMap(scriptingGui)
     {
         return scriptingGui.controller.htmlFileMap();
     }

     function toHtmlNameMap(scriptingGui)
     {
         return scriptingGui.nameMap;
     }

     function toHtmlConsoleMap(scriptingGui)
     {
         return scriptingGui.console.toHtmlMap();
     }
     
     
     function guiName()
     {
         return 'ishmaelEditor';
     }


     function getGuiText()
     {

         var returner = "sirikata.ui('" + guiName() + "',";
         returner += 'function(){ ';

         returner += @

         function ishmaelWindowId()
         {
             return 'ishmael__windowID_';
         }

         //the div that surrounds all the nearby objects.
         function nearbyListId()
         {
             return 'ishmael__nearbyListID__';
         }

         //the div that surrounds all the scripted objects.
         function scriptedListId()
         {
             return 'ishmael__scriptedListID__';
         }


         function actionListId()
         {
             return 'ishmael__actionListID__';
         }

         function actionTareaId()
         {
             return 'ishmael__actionEditor__';
         }
         
         function saveActionButtonId()
         {
             return 'ishmael__saveActionButton__';
         }

         function execActionButtonId()
         {
             return 'ishmael__execActionButton__';
         }

         function newActionButtonId()
         {
             return 'ishmael__newActionButton__';
         }

         function removeActionButtonId()
         {
             return 'ishmael__removeActionButton__';
         }

         function fileSelectId()
         {
             return 'ishmael__fileSelectId__';
         }


         function addFileButtonId()
         {
             return 'ishmael__addFileButtonId__';
         }

         function updateAndSendFileButtonId()
         {
             return 'ishmael__updateAndSendFileButtonId__';
         }

         function updateAndSendAllFilesButtonId()
         {
             return 'ishmael__updateAndSendAllFilesButtonId__';
         }

         function removeFileButtonId()
         {
             return 'ishmael__removeFileButtonId__';
         }
         

         function renameVisibleButtonId()
         {
             return 'ishmael__renameVisibleId__';
         }

         function consoleId()
         {
             return 'ishmael__consoleId__';
         }

         function actionDivId()
         {
             return 'ishmael__actionDivId__';
         }

         function fileDivId()
         {
             return 'ishmael__fileDivId__';
         }

         function actionFileTabId()
         {
             return 'ishmael__actionFileTabId__';
         }

         function nearbyScriptedTabId()
         {
             return 'ishmael__nearbyScriptedTabId__';
         }
         
         /**
          \param {String} nearbyObj (id of visible that we are
          communicating with).
          gives the div for each nearby object.
          */
         function generateNearbyDivId(nearbyObj)
         {
             var visIdDivable = divizeVisibleId(nearbyObj);
             return 'ishmael__nearbyDivID___' + visIdDivable;
         }


         
         /**
          \param {String} scriptedObj (id of visible that we are
          communicating with).
          gives the div for each scripted object.
          */
         function generateScriptedDivId(scriptedObj)
         {
             var visIdDivable = divizeVisibleId(scriptedObj);
             return 'ishmael__scriptedDivID___' + visIdDivable;
         }

         
         function divizeVisibleId(visId)
         {
             return visId.replace(':','');
         }
         

         $('<div>'   +
           
           //which presences are available
           '<div id="' + nearbyScriptedTabId() + '">' +
           '<ul>' +
		'<li><a href="#' + scriptedListId() +'">Scripted</a></li>' +
		'<li><a href="#' + nearbyListId() +'">Nearby</a></li>' +
	   '</ul>' +

              '<select id="'     + scriptedListId() + '" size=5>' +
              '</select><br/>'   +

              '<select id="'     + nearbyListId() + '" size=5>'   +
              '</select><br/>'   +

              '<button id="' + renameVisibleButtonId() + '">' +
              'rename' +
              '</button>'    +
 
           '</div>' + //closes scripted/nearby tab div

           
           //action file gui
           '<div id="' + actionFileTabId() + '">' +

           '<ul>' +
		'<li><a href="#' + actionDivId() +'">Actions</a></li>' +
		'<li><a href="#' + fileDivId() +'">Files</a></li>' +
	   '</ul>' +
           
              //action gui
              '<div id="'+actionDivId() + '">' + 
              '<table><tr><td>'+
              '<select id="'     + actionListId() + '" size=5>'   +
              '</select>'        +
              '</td><td>' +
           
              '<div id="'   + actionTareaId()+ '"  style="min-width:400px;min-height:100px;max-width:400px;position:relative;margin:0;padding:0;">' +
              '</div>'      + //closes actionTareaDiv
              '</td></tr></table>' +
           
              '<button id="'     + saveActionButtonId()    + '">' +
              'save action'      +
              '</button>'        +

              '<button id="'     + execActionButtonId()    + '">' +
              'exec&save action' +
              '</button>'        +

              '<button id="'     + newActionButtonId()     + '">' +
              'new action'       +
              '</button>'        +

              '<button id="'     + removeActionButtonId()  + '">' +
              'remove action'    +
              '</button>'        +
              '</div>'   + //closes action div


              //file gui
              '<div id="' +fileDivId() + '">' +
              '<select id="'     + fileSelectId() + '" size=5 style="min-width:200px">'   +
              '</select><br/>'        +

              '<button id="'+ addFileButtonId() + '">' +
              'add file' +
              '</button>'+

              '<button id="'+ updateAndSendFileButtonId() + '">' +
              'update and send file' +
              '</button>'+

              '<button id="'+ updateAndSendAllFilesButtonId() + '">' +
              'update and send all files' +
              '</button>'+

              '<button id="' + removeFileButtonId() + '">' +
              'remove file' +
              '</button>'   +

              '</div>' + //closes file div


           '</div>' + //closes tab div
           
           //console
           '<b>Console</b><br/>' +
           '<div id="' + consoleId() + '" style="min-width:500px;max-width:550px;min-height:250px;position:relative;margin:0;padding:0;">'  +
           '</div>' +

           
           '</div>' //end div at top.
          ).attr({id:ishmaelWindowId(),title:'ishmael'}).appendTo('body');


         var jsMode = require('ace/mode/javascript').Mode;
         var actionEditor = ace.edit(actionTareaId());
         actionEditor.setTheme('ace/theme/dawn');
         actionEditor.getSession().setMode(new jsMode());

         var consoleEditor = ace.edit(consoleId());
         consoleEditor.setTheme('ace/theme/dawn');
         consoleEditor.getSession().setMode(new jsMode());
         consoleEditor.renderer.setShowGutter(true);
         consoleEditor.setReadOnly(true);

         var $tabs = $('#' +actionFileTabId());
         $tabs.tabs();

         $tabs = $('#' + nearbyScriptedTabId());
         $tabs.tabs();
         
         
         //The id of the visible that the scripter has selected to
         //program.
         var currentlySelectedVisible = undefined;
         
         //int id of the currently selected action.
         var currentlySelectedAction = undefined;
         //map from int to std.ScriptingGui.Action objects.  It gets
         //updated whenever we received an ishmaelRedraw call.  Note
         //that the redraw call will not write over the text of
         //currentlySelectedAction.  This ensures that scripter
         //edits will not be lost while they are being written if some
         //other action triggers a call to ishmaelRedraw (for
         //instance, a new nearbyObject gets added).
         var allActions = undefined;

         var currentlySelectedFile = undefined;
         var allFiles = undefined;

         var allConsoleHistories = undefined;
         
         $('#' + scriptedListId()).change(
             function()
             {
                 //loads the visible id 
                 var val = $('#' + scriptedListId()).val();

                 //updates currentlySelectedVisible and the display of
                 //the files that should be associated with it.
                 changeCurrentlySelectedVisible(val);

                 //if we change which visible we're scripting from the
                 //scripting selection menu, we want that change to be
                 //reflected in the nearby selection list.
                 updateNearbySelection(val.toString());
             });
         
         //set a listener for action list.  whenever select an option,
         //should communicate that to emerson gui, so that can keep
         //track of selected action.
         $('#' + actionListId()).change(
             function()
             {
                 var val = 
                     $('#' + actionListId()).val();
                 changeActionText(parseInt(val));
                 sirikata.log('error', 'Selected action: '  + val.toString());
             });

         
         $('#' + nearbyListId()).change(
             function()
             {
                 var val = $('#'+nearbyListId()).val();
                 //updates currentlySelectedVisible and the display of
                 //the files that should be associated with it.
                 changeCurrentlySelectedVisible(val);
                 sirikata.event('addVisible',val);
             });


         /**
          \param {String} newVisible -- id of the new visible to set
          currentlySelectedVisible to.

          This function changes currentlySelectedVisible as well as
          updating the file fields that should be associated with that
          visible.
          */
         function changeCurrentlySelectedVisible(newVisible)
         {
             currentlySelectedVisible = newVisible;
             //ensures that file list gets updated as well.
             redrawFileSelect(allFiles);
             redrawConsole(allConsoleHistories);
         }


         $('#' + renameVisibleButtonId()).click(
             function()
             {
                 if (typeof(currentlySelectedVisible)== 'undefined')
                     return;

                 var currentName =
                     $('#' + generateScriptedDivId(currentlySelectedVisible)).html();
                 
                 sirikata.event(
                     'renameVisible',currentlySelectedVisible,currentName);
             });
         
         //when hit save, sends the action text through to controller
         //to save it.
         $('#' + saveActionButtonId()).click(
             function()
             {
                 //no action is selected
                 if ((typeof(currentlySelectedAction) == 'undefined') ||
                     (currentlySelectedAction === null))
                     return;


                 //var toSaveText = $('#' + actionTareaId()).val();
                 var toSaveText = actionEditor.getSession().getValue();
                 
                 //saving action does not force a redraw.  must
                 //preserve new text in allActions on our end. (takes
                 //care of failure case where save an action, then
                 //click on another action, then return to current
                 //action).
                 allActions[currentlySelectedAction].text = toSaveText;
                 
                 sirikata.event(
                     'saveAction',currentlySelectedAction,toSaveText);
             });


         //saves and executes current action
         $('#' + execActionButtonId()).click(
             function()
             {
                 if ((typeof(currentlySelectedAction)  == 'undefined') ||
                     (typeof(currentlySelectedVisible) == 'undefined'))
                 {
                     sirikata.log(
                         'error','Cannot execute action.  ' +
                             'No vis or action selected.');
                     return;
                 }

                 //see comments in click handler for saveActionButton.
                 var toSaveText = actionEditor.getSession().getValue();

                 allActions[currentlySelectedAction].text = toSaveText;
                 sirikata.event(
                     'saveAndExecuteAction',currentlySelectedAction,
                     toSaveText,currentlySelectedVisible);
             });


         //user asks for new action: we pass event down to
         //scriptingGui, which creates a simpleInput asking for new
         //action name.
         $('#' + newActionButtonId()).click(
             function()
             {
                 sirikata.event('newAction');
             });
         
         $('#' + removeActionButtonId()).click(
             function()
             {
                 if (typeof(currentlySelectedAction) == 'undefined')
                     return;
                 
                 sirikata.event('removeAction',currentlySelectedAction);
                 currentlySelectedAction = undefined;
             });


         $('#' + fileSelectId()).change(
             function()
             {
                 currentlySelectedFile = $('#' + fileSelectId()).val();
             });
         

         $('#' + addFileButtonId()).click(
             function()
             {
                 if (typeof(currentlySelectedVisible)=='undefined')
                     return;

                 sirikata.event('addFile',currentlySelectedVisible);
             });

         $('#' + updateAndSendFileButtonId()).click(
             function()
             {
                 if ((typeof(currentlySelectedVisible) == 'undefined') ||
                     (typeof(currentlySelectedFile) == 'undefined'))
                 {
                     return;
                 }
                 sirikata.event(
                     'updateAndSendFile',currentlySelectedVisible,
                     currentlySelectedFile);
             });


         $('#' + updateAndSendAllFilesButtonId()).click(
             function()
             {
                 if (typeof(currentlySelectedVisible) == 'undefined')
                     return;

                 sirikata.event(
                     'updateAndSendAllFiles',currentlySelectedVisible);
             });

         $('#' + removeFileButtonId()).click(
             function()
             {
                 if ((typeof(currentlySelectedVisible) == 'undefined') ||
                     (typeof(currentlySelectedFile) == 'undefined'))
                 {
                     return;
                 }

                 sirikata.event(
                     'removeFile',currentlySelectedVisible,currentlySelectedFile);

             });
         
         
         var inputWindow = new sirikata.ui.window(
             '#' + ishmaelWindowId(),
                 {
	             autoOpen: true,
	             height: 'auto',
	             width: 600,
                     height: 850,
                     position: 'right'
                 }
             );
         inputWindow.show();


         

         /**
          changes selection in updateNearby to the one associated with
          visibleId (if it's available).  If it's not, then we just
          unselect.

          Right now, we take a performance hit, because the selection
          change that we do here will trigger the .change handler
          associated with nearbyList.  Should still maintain semantics
          though.
          */
         function updateNearbySelection(visibleId)
         {
             var nearbyOption = $('#' + generateNearbyDivId(visibleId));
             if (nearbyOption.size())
             {
                 //means that the element did exist.  now want it to
                 //appear selected in nearbyList.
                 var nearbyVal = nearbyOption.val();
                 $('#' + nearbyListId()).val(nearbyVal);
             }
             else
             {
                 var errMsg =
                     'In updatenearbyselection attempting '+
                     'to set selector to none.';
                 
                 sirikatal.log('error',errMsg);
                 $('#' + nearbyListId()).val(null);                     
             }
         }


         /**
          \param {int or undefined} idActSelected.  If an int, then
          looks through record of allActions, and sets action text
          area to that.  If undefined, then clears action text area.
          */
         function changeActionText(idActSelected)
         {
             currentlySelectedAction = idActSelected;
             var textToSetTo = '';
             
             if (typeof(idActSelected) !='undefined')
             {
                 if (! idActSelected in allActions)
                 {
                     sirikata.log('error','action ids out of ' +
                                  'sync with actions in scripting gui.');
                     return;
                 }
                 textToSetTo = allActions[idActSelected].text;
             }

             //actually update textarea with correct text
             actionEditor.getSession().setValue(textToSetTo);
         }
         
         
         /**
          \param {object: <int:std.ScriptingGui.Action>} actionMap

          
          \param {object: <string (visibleId):
              object: <string(filename):string(filename)>>} fileMap --
          keyed by visible id, elements are maps of files that each
          remote visible has on it.

          \param {object: <string visId: actual name>} nameMap

          \param {object: <string visId: array of console history>}
          consoleMap.
          */
         ishmaelRedraw = function(
             nearbyObjs,scriptedObjs,actionMap,fileMap,
             nameMap,consoleMap)
         {
             redrawNearby(nearbyObjs,nameMap);
             redrawScriptedObjs(scriptedObjs,nameMap);
             redrawActionList(actionMap);
             redrawFileSelect(fileMap);
             redrawConsole(consoleMap);
         };

         
         /**
          \param {object: <string (visibleId): string (visibleId)>}
          nearbyObjs -- all objects that are in vicinity.

          \param {object: <string (visId): string (name)>} nameMap
          */
         function redrawNearby(nearbyObjs, nameMap)
         {
             var newHtml = '';
             for (var s in nearbyObjs)
             {
                 if (s===currentlySelectedVisible)
                     newHtml += '<option selected ';
                 else
                     newHtml += '<option ';

                 newHtml += 'value="' + s + '" ';
                 newHtml += 'id="' + generateNearbyDivId(s) + '">';
                 if (s in nameMap)
                     newHtml += nameMap[s];
                 else
                     newHtml += s;
                 newHtml += '</option>';
             }
             $('#' + nearbyListId()).html(newHtml);
         }


         /**
          \param {object: <string (visibleId): string(visibleId)>}
          scriptedObjs -- all objects that we have a scripting
          relationship with.
          */
         function redrawScriptedObjs(scriptedObjs,nameMap)
         {
             var newHtml = '';
             for (var s in scriptedObjs)
             {
                 if (s === currentlySelectedVisible)
                     newHtml += '<option selected ';
                 else
                     newHtml += '<option ';
                 
                 newHtml += 'value="' +s +  '" ';
                 newHtml += 'id="' + generateScriptedDivId(s) + '">';
                 
                 if (s in nameMap)
                     newHtml += nameMap[s];
                 else
                     newHtml += s;
                 newHtml += '</option>';
             }
             $('#' + scriptedListId()).html(newHtml);
         }



         function redrawActionList(actionMap)
         {
             var prevCurAct = null;
             if (typeof(currentlySelectedAction) != 'undefined')
             {
                 prevCurAct = allActions[currentlySelectedAction];
                 //update with text that had entered in tarea.
                 //prevCurAct.text = $('#' + actionTareaId()).val();
                 prevCurAct.text = actionEditor.getSession().getValue();
             }

             allActions = actionMap;
             //preserves edits that scripter was potentially making
             //when other action triggered redraw (eg. a new nearby
             //object).
             if (prevCurAct !== null)
                 allActions[prevCurAct.id] = prevCurAct;

             
             var newHtml = '';
             for (var s in actionMap)
             {
                 if (parseInt(s) === parseInt(currentlySelectedAction))
                     newHtml += '<option selected ';
                 else
                     newHtml += '<option ';

                 newHtml += 'value="' + s + '">';
                 newHtml += actionMap[s].name ;
                 newHtml += '</option>';
             }

             $('#' + actionListId()).html(newHtml);
         }

         /**
          \param {object: <string (visibleId):
              object: <string(filename):string(filename)>>} fileMap --
          keyed by visible id, elements are maps of files that each
          remote visible has on it.

          (fileMap can also be undefined if called from
          changeCurrentlySelectedVisible.)
          
          Sets currentlySelectedFile to undefined if have no
          currentlySelectedFile that exists in list of files under
          currentlySelectedVisible.  This ensures that
          changeCurrentlySelectedVisible can call this function
          whenever want to update files after having updated
          currentlySelectedVisible.
          */
         function redrawFileSelect(fileMap)
         {
             if (typeof(allFiles) == 'undefined')
                 allFiles = fileMap;

             //no work to do.
             if(typeof(allFiles) == 'undefined')
                 return;
             
             //no visible selected, and hence no list of files to
             //show.
             if (typeof(currentlySelectedVisible) == 'undefined')
             {
                 currentlySelectedFile = undefined;
                 return;                     
             }


             var visFiles = fileMap[currentlySelectedVisible];
             var newHtml = '';
             var haveSelectedFile = false;
             for (var s in visFiles)
             {
                 if (s === currentlySelectedFile)
                 {
                     newHtml += '<option selected ';
                     haveSelectedFile = true;
                 }
                 else
                     newHtml += '<option ';

                 newHtml += 'value="' + s + '">';
                 newHtml += visFiles[s];
                 newHtml += '</option>';
             }

             if (!haveSelectedFile)
                 currentlySelectedFile = undefined;
             
             $('#' + fileSelectId()).html(newHtml);
         }
         


         /**         
         can be called from ishmaelRedraw (using new consoleHistories)
         or from changeCurrentlySelectedVisible (using old
         allConsoleHistories).
          */
         function redrawConsole(consoleMap)
         {
             allConsoleHistories = consoleMap;
             
             if ((typeof(currentlySelectedVisible) == 'undefined') ||
                (!(currentlySelectedVisible in allConsoleHistories))) 
             {
                 consoleEditor.getSession().setValue('');
                 return;
             }

             
             var consoleEntry =
                 allConsoleHistories[currentlySelectedVisible];
             var consMsg = '';
             
             for (var s in consoleEntry)
             {
                 consMsg += consoleEntry[s];
                 consMsg += '\\n\\n';
             }
             consoleEditor.getSession().setValue(consMsg);
         }

         
         @;
         
         returner += '});';         
         return returner;
     }
 })();


//do all further imports for file and gui control.
system.require('controller.em');
system.require('action.em');
system.require('console.em');
system.require('fileManagerElement.em');