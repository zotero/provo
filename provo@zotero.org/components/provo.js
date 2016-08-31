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

var Zotero, translatorsDir, outputDir, suffix;
var collectedResults = {};

const BOOKMARKLET_FILES = ["common.js", "common_ie.js", "ie_hack.js", "iframe.html",
	"iframe.js", "iframe_ie.html", "iframe_ie.js", "tests/inject_test.js",
	"tests/inject_ie_test.js"];

function readPathArgument(cmdLine, arg) {
	var outputDirString = cmdLine.handleFlagWithParam(arg, false);
	if(!outputDirString) {
		Zotero.debug("Provo: "+arg+" not specified; exiting", 1);
		exit();
	}
	var outputDir = Components.classes["@mozilla.org/file/local;1"].
			createInstance(Components.interfaces.nsILocalFile);
	outputDir.initWithPath(outputDirString);
	if(!outputDir.exists()) {
		Zotero.debug("Provo: "+arg+" does not exist; exiting", 1);
		exit();
	}
	return outputDir;
}

function Provo() {}
Provo.prototype = {
	/* nsICommandLineHandler */
	handle: function(cmdLine) {
		// Initialize Zotero
		Zotero = Components.classes["@zotero.org/Zotero;1"]
			.getService(Components.interfaces.nsISupports)
			.wrappedJSObject;

		outputDir = readPathArgument(cmdLine, "provooutputdir");
		var payloadDir = readPathArgument(cmdLine, "provopayloaddir");
		
		// Suffix is optional
		suffix = cmdLine.handleFlagWithParam("provosuffix", false);
		if(!suffix) suffix = "";
		
		// Add endpoints
		Zotero.Server.Endpoints["/provo/run"] = ProvoRun;
		Zotero.Server.Endpoints["/provo/save"] = ProvoSave;
		for(var i=0; i<BOOKMARKLET_FILES.length; i++) {
			var file = BOOKMARKLET_FILES[i],
				fileParts = file.split("/"),
				filePath = payloadDir.clone();
			for(var j=0; j<fileParts.length; j++) filePath.append(fileParts[j]);

			Zotero.Server.Endpoints["/provo/bookmarklet/"+file] = getFileEndpoint(filePath);
		}
		
		// Allow 60 seconds for startup to complete and then start running translator tester
		if(cmdLine.handleFlag("provorun", false)) {
			let timeout = 60000;
			Zotero.setTimeout(function() {
				Zotero_TranslatorTesters.runAllTests(
					1,
					{},
					function (results, last) {
						collectResults(Zotero.browser, Zotero.version, results, last);
					}
				);
			}, timeout);
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
 * Trigger translator tests
 */
var ProvoRun = function() {};
ProvoRun.prototype = {
	"supportedMethods":["GET"],
	
	"init":function(data, sendResponseCallback) {
		sendResponseCallback(200, "text/plain", "fnord");
	}
};

/**
 * Save translator test data
 */
var ProvoSave = function() {};
ProvoSave.prototype = {
	"supportedMethods":["POST"],
	"supportedDataTypes":["application/json"],
	
	"init":function(data, sendResponseCallback) {
		writeData(data, true);
		sendResponseCallback(200, "text/plain", "OK");
	}
};

/**
 * Serve a text file
 */
function getFileEndpoint(file) {
	var contents = Zotero.File.getContents(file),
		leafName = file.leafName,
		ext = leafName.substr(leafName.lastIndexOf(".")),
		mimeType = ext == ".js" ? "application/javascript" : "text/html";

	var endpoint = function() {};
	endpoint.prototype = {
		"supportedMethods":["GET"],
		"init":function(data, sendResponseCallback) {
			sendResponseCallback(200, mimeType, contents);
		}
	};
	return endpoint;
}

function collectResults(browser, version, results, last) {
	if (!collectedResults[browser]) {
		collectedResults[browser] = {
			[version]: []
		};
	}
	var o = collectedResults[browser][version];
	o.push(results);
	
	//
	// TODO: Only do the below every x collections, or if last == true
	//
	// Sort results
	if ("getLocaleCollation" in Zotero) {
		let collation = Zotero.getLocaleCollation();
		var strcmp = function (a, b) {
			return collation.compareString(1, a, b);
		};
	}
	else {
		var strcmp = function (a, b) {
			return a.toLowerCase().localeCompare(b.toLowerCase());
		};
	}
	o.sort(function (a, b) {
		if (a.type !== b.type) {
			return TEST_TYPES.indexOf(a.type) - TEST_TYPES.indexOf(b.type);
		}
		return strcmp(a.label, b.label);
	});
	
	writeData(
		{
			browser,
			version,
			results: o
		},
		last
	);
}

/**
 * Serialize output to a file
 */
function writeData(data, done) {
	var outputFile = outputDir.clone();
	var outputFileName = "testResults-" + data.browser + (suffix ? "-" + suffix : "") + ".json";
	outputFile.append(outputFileName + ".tmp");
	Zotero.File.putContents(outputFile, JSON.stringify(data, null, "\t"));
	
	if (done) {
		// Remove .tmp extension
		outputFile.moveTo(null, outputFileName);
		
		// Create updated index of output directory
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
}

/**
 * Quit Zotero/Firefox
 */
function exit() {
	// Quit
	Components.classes['@mozilla.org/toolkit/app-startup;1']
		.getService(Components.interfaces.nsIAppStartup)
		.quit(Components.interfaces.nsIAppStartup.eAttemptQuit);
}


var NSGetFactory = XPCOMUtils.generateNSGetFactory([Provo]);