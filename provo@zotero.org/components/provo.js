"use strict";
/*
    ***** BEGIN LICENSE BLOCK *****
    
    Copyright © 2012 Center for History and New Media
                     George Mason University, Fairfax, Virginia, USA
                     http://zotero.org
    
    This file is part of Zotero.
    
    Zotero is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    Zotero is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.
    
    You should have received a copy of the GNU Affero General Public License
    along with Zotero.  If not, see <http://www.gnu.org/licenses/>.
    
    ***** END LICENSE BLOCK *****
*/
Components.utils.import("resource://gre/modules/Services.jsm");
Components.utils.import("resource://gre/modules/FileUtils.jsm");
Components.utils.import("resource://gre/modules/XPCOMUtils.jsm");
Components.utils.import("chrome://zotero/content/tools/testTranslators/translatorTester.js");

var Zotero, translatorsDir, outputDir, suffix, _waitingForBrowsers = {};

function Provo() {}
Provo.prototype = {
	/* nsICommandLineHandler */
	handle: function(cmdLine) {
		// Initialize Zotero
		Zotero = Components.classes["@zotero.org/Zotero;1"]
			.getService(Components.interfaces.nsISupports)
			.wrappedJSObject;
		
		// Check output directory
		var outputDirString = cmdLine.handleFlagWithParam("provooutputdir", false);
		if(!outputDirString) {
			Zotero.debug("Provo: No output directory specified; exiting", 1);
			exit();
		}
		outputDir = Components.classes["@mozilla.org/file/local;1"].
				createInstance(Components.interfaces.nsILocalFile);
		outputDir.initWithPath(outputDirString);
		if(!outputDir.exists()) {
			Zotero.debug("Provo: Output directory does not exist; exiting", 1);
			exit();
		}
		
		// Check browsers
		var provoBrowsersString = cmdLine.handleFlagWithParam("provobrowsers", false);
		if(!provoBrowsersString) {
			Zotero.debug("Provo: No browsers specified; exiting", 1);
			exit();
		}
		var browsers = provoBrowsersString.split(",");
		for each(var browser in browsers) {
			_waitingForBrowsers[browser] = true;
		}
		
		// Suffix is optional
		suffix = cmdLine.handleFlagWithParam("provosuffix", false);
		if(!suffix) suffix = "";
		
		// Add endpoint
		Zotero.Server.Endpoints["/provo/save"] = ProvoSave;
		
		// Allow 60 seconds for startup to complete and then start running translator tester
		if(_waitingForBrowsers["g"]) {
			Zotero.setTimeout(function() {
				Zotero_TranslatorTesters.runAllTests(6, {}, writeData);
			}, 60000);
		}
	},
	
	contractID: "@mozilla.org/commandlinehandler/general-startup;1?type=provo",
	classDescription: "Provo Command Line Handler",
	classID: Components.ID("{aa868e19-3594-4324-ab52-68d608453815}"),
	service: true,
	_xpcom_categories: [{category:"command-line-handler", entry:"m-provo"}],
	QueryInterface: XPCOMUtils.generateQI([Components.interfaces.nsICommandLineHandler,
	                                       Components.interfaces.nsISupports])
};

/**
 * Save translator test data
 */
var ProvoSave = function() {};
ProvoSave.prototype = {
	"supportedMethods":["POST"],
	"supportedDataTypes":["application/json"],
	
	"init":function(data, sendResponseCallback) {
		writeData(data);
		sendResponseCallback(200, "text/plain", "OK");
	}
};

/**
 * Serialize output to a file
 */
function writeData(data) {
	var outfile = outputDir.clone();
	outfile.append("testResults-"+data.browser+(suffix ? "-"+suffix : "")+".json");
	delete _waitingForBrowsers[data.browser];
	Zotero.File.putContents(outfile, JSON.stringify(data, null, "\t"));
	if(Zotero.Utilities.isEmpty(_waitingForBrowsers)) Zotero.setTimeout(exit, 0);
}

/**
 * Quit Zotero/Firefox
 */
function exit() {
	// Create index of output directory
	if(outputDir && outputDir.exists()) {
		var index = [];
		var directoryEntries = outputDir.directoryEntries;
		while(directoryEntries.hasMoreElements()) {
			var filename = directoryEntries.getNext()
				.QueryInterface(Components.interfaces.nsILocalFile).leafName;
			if(/\.json$/.test(filename) && filename !== "index.json") {
				index.push(filename);
			}
		}
		
		var indexFile = outputDir.clone();
		indexFile.append("index.json");
		Zotero.File.putContents(indexFile, JSON.stringify(index, null, "\t"));
	}
	
	// Quit
	Components.classes['@mozilla.org/toolkit/app-startup;1']
		.getService(Components.interfaces.nsIAppStartup)
		.quit(Components.interfaces.nsIAppStartup.eAttemptQuit);
}


var NSGetFactory = XPCOMUtils.generateNSGetFactory([Provo]);