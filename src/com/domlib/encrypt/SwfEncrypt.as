package com.domlib.encrypt
{
	import com.domlib.utils.CodeUtil;
	import com.domlib.utils.FileUtil;
	import com.domlib.utils.StringUtil;
	import com.swfdiy.data.ABC;
	import com.swfdiy.data.SWF;
	import com.swfdiy.data.SWFTag;
	import com.swfdiy.data.SWFTag.TagDoABC;
	
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	
	import nochump.util.zip.ZipEntry;
	import nochump.util.zip.ZipFile;
	
	
	/**
	 * SWF混淆工具
	 * @author dom
	 */
	public class SwfEncrypt extends EventDispatcher
	{
		public function SwfEncrypt()
		{
			super();
		}
		
		/**
		 * 要排除的关键字
		 */		
		private var excludeDic:Dictionary = new Dictionary();
		/**
		 * 包路径字典
		 */		
		private var packageDic:Dictionary = new Dictionary();
		/**
		 * 要混淆的关键字列表
		 */		
		private var keyList:Array = [];
		/**
		 * 要混淆的包名列表
		 */		
		private var packageList:Array = [];
		/**
		 * 目标项目路径
		 */		
		private var targetSrc:String = "";
		
		private var dirNames:Object = {};
		/**
		 * 开始混淆 
		 * @param srcPaths 要混淆的src源码路径列表
		 * @param excludeSwfs 要排除关键字的外部swf/swc路径列表
		 * @param targetSrc 要发布到的src路径列表
		 * @param keyWordPath 可选,载入上一次使用的关键字映射表,若有增加，则同时写入。
		 */		
		public function startMixUp(srcPaths:Array,excludeSwfs:Array,
								   targetSrc:String,keyWordPath:String="",excludeKeys:Array = null):void
		{
			excludeDic = new Dictionary();
			packageDic = new Dictionary();
			keyList = [];
			packageList = [];
			targetSrc = new File(targetSrc).nativePath;
			targetSrc = FileUtil.escapeUrl(targetSrc)+"/";
			this.targetSrc = targetSrc;
			
			var list:Array = [];
			dirNames = {};
			for each(var srcPath:String in srcPaths)
			{
				FileUtil.search(srcPath,null,dirFilterFunc);
				list = list.concat(FileUtil.search(srcPath,""));
			}
			for each(var file:File in list)
			{
				if(file.isDirectory)
					continue;
				if(file.parent.name=="src" || !file.extension || ( extensions.indexOf(file.extension.toLowerCase())<0 ))
				{
					var name:String = FileUtil.getFileName(file.nativePath);
					excludeDic[name] = true;
				}
				if(!file.extension || ( extensions.indexOf(file.extension.toLowerCase())<0 ))
					continue;
				if(file.extension.toLowerCase()=="as")
				{
					var text:String = FileUtil.openAsString(file.nativePath);
					checkAsFile(text);
				}
				else
				{
					try
					{
						var xmlStr:String = FileUtil.openAsString(file.nativePath);
						var xml:XML = new XML(xmlStr);
						checkXmlFile(xml);
					}
					catch(e:Error){}
				}
			}
			
			readKeyFromExcludeSwf(excludeSwfs);
			if(excludeKeys != null)
			{
				readKeyFromExcludeKeys(excludeKeys);
			}
			var analyzer:ClassAnalyzer = new ClassAnalyzer();
			for each(var path:String in srcPaths)
			{
				analyzer.startAnalyze(path);
				list = analyzer.getPackageList;
				for each(var key:String in list)
				{
					if(propList.indexOf(key)!=-1)
						continue;
					packageDic[key] = true;
					if(excludeDic[key]===undefined&&isNaN(Number(key)))
					{
						var prefix:String = getPrefix(key);
						if(excludeDic[prefix]===undefined)
						{
							if(packageList.indexOf(key)==-1)
								packageList.push(key);
						}
					}
				}
				list = analyzer.keyList;
				for each(key in list)
				{
					if(propList.indexOf(key)!=-1)
						continue;
					if(excludeDic[key]===undefined&&isNaN(Number(key)))
					{
						prefix = getPrefix(key);
						if(excludeDic[prefix]===undefined)
						{
							if(keyList.indexOf(key)==-1)
								keyList.push(key);
						}
					}
				}
			}
			for(var i:int=keyList.length-1;i>=0;i--)
			{
				key = keyList[i];
				if(dirNames[key])
				{
					keyList.splice(i,1);
				}
				else
				{
					for(var p:String in packageDic)
					{
						var index:int = p.indexOf(key);
						if(index!=-1&&isFullWord(p,index,index+key.length))
						{
							keyList.splice(i,1);
							break;
						}
					}
				}
			}
			
			generateFiles(srcPaths,keyWordPath);
		}
		
		private function dirFilterFunc(file:File):Boolean
		{
			if(file.isDirectory&&file.name.charAt(0)!=".")
			{
				dirNames[file.name] = true;
				return true;
			}
			return false;
		}
		
		//搜索的扩展名
		private var extensions:Vector.<String> = new <String>["as","xml","mxml"];
		//搜索回调函数
		private function filterFunc(file:File):Boolean
		{
			if(file.isDirectory)
			{
				if(file.name.charAt(0)!=".")
					return true;
			}
			else if(file.extension&&extensions.indexOf(file.extension)!=-1)
			{
				return true;
			}
			return false;
		}
		
		/**
		 * Dictionary自身的关键字列表 
		 */		
		private var propList:Vector.<String> =  
			new <String>["hasOwnProperty","isPrototypeOf","valueOf",
				"propertyIsEnumerable","setPropertyIsEnumerable","toString"];
		
		/**
		 * 获取as文件内的关键字
		 */		
		private function checkAsFile(data:String):void
		{
			var lines:Array = data.split("\n");
			var length:int = lines.length;
			var strLen:int;
			var line:String;
			var charCode:Number;
			var isNoteStart:Boolean = false;
			var index:int;
			var k:int;
			var noteStart:String = "/**";
			var noteEnd:String = "*/";
			
			for(var i:int=0;i<length;i++)
			{
				line = lines[i];
				line = line.split("\\n").join("{line}");
				line = line.split("\\r").join("{enter}");
				line = line.split("\\t").join("{tab}");
				line = line.split("\\\"").join("{quote}");
				line = line.split("\\'").join("{squote}");
				
				index = 0;
				strLen = line.length;
				if(isNoteStart)
				{
					index = line.indexOf(noteEnd);
					if(index==-1)
					{
						continue;
					}
					else
					{
						isNoteStart = false;
						index += 2;
					}
				}
				else
				{
					index = line.indexOf(noteStart);
					if(index!=-1)
					{
						strLen = index;
						index = 0;
						isNoteStart = true;
					}
				}
				k = line.indexOf("//");
				if(k!=-1)
					strLen = k;
				
				var quoteStart:Boolean = false;
				var quote:String = "\"";
				var quoteIndex:int;
				var keys:Array = [];
				for(var j:int=index;j<strLen;j++)
				{
					var char:String = line.charAt(j);
					if(quoteStart)
					{
						if(char==quote)
						{
							keys.push(line.substring(quoteIndex,j));
							quoteStart = false;
						}
					}
					else
					{
						if(char=="\""||char=="'")
						{
							quoteStart = true;
							quoteIndex = j+1;
							quote = char;
						}
					}
					
				}
				
				for each(var key:String in keys)
				{
					key = key.split("{line}").join("\n");
					key = key.split("{tab}").join("\t");
					key = key.split("{enter}").join("\r");
					key = key.split("{quote}").join("\"");
					key = key.split("{squote}").join("'");
					if(propList.indexOf(key)==-1&&isNaN(Number(key)))
						excludeDic[key] = true;
				}
			}
		}
		
		/**
		 * 从swf文件中读取要排除的关键字,并返回最终要混淆的关键字列表.
		 */		
		private function readKeyFromExcludeSwf(paths:Array):void
		{
			var strings:Array = [];
			for each(var path:String in paths)
			{
				var bytes:ByteArray = FileUtil.openAsByteArray(path);
				var file:File = File.applicationDirectory.resolvePath(path);
				if(file.extension=="swc")
				{
					try
					{
						var zipFile:ZipFile = new ZipFile(bytes);   
						var zipEntry:ZipEntry = zipFile.getEntry("library.swf");   
						bytes = zipFile.getInput(zipEntry);
					}
					catch(e:Error)
					{
						continue;
					}
				}
				var swf:SWF = new SWF(bytes);
				swf.startReadTags();	
				var tag:SWFTag = swf.read_tag();
				while(tag) 
				{
					if(tag is TagDoABC) 
					{
						var abc:ABC = TagDoABC(tag).abc();
						strings = strings.concat(abc.constant_pool.strings);
					}
					tag = swf.read_tag();
				}
			}
			for each(var key:String in strings)
			{
				if(propList.indexOf(key)==-1&&isNaN(Number(key)))
				{
					if(key.indexOf(".")!=-1)
					{
						packageDic[key] = true;
					}
					excludeDic[key] = true;
				}
			}
		}
		
		
		/**从中要排除的关键字列表中读取要排除的关键字,并返回最终要混淆的关键字列表*/
		private function readKeyFromExcludeKeys(excludeKeys:Array):void
		{
			for each(var key:String in excludeKeys)
			{
				if(propList.indexOf(key)==-1&&isNaN(Number(key)))
				{
					if(key.indexOf(".")!=-1)
					{
						packageDic[key] = true;
					}
					excludeDic[key] = true;
				}
			}
		}
		
		/**
		 * 去除key末尾的数字序号
		 */		
		private function getPrefix(key:String):String
		{
			var index:int = key.length-1;
			while(index>0)
			{
				var char:String = key.charAt(index);
				if(char>="0"&&char<="9")
				{
					index--;
				}
				else
				{
					break;
				}
			}
			return key.substring(0,index+1);
		}
		
		
		private var fxNs:Namespace = new Namespace("fx","http://ns.adobe.com/mxml/2009");
		/**
		 * 获取xml文件内的关键字
		 */		
		private function checkXmlFile(xml:XML):void
		{
			var key:String = xml.localName();
			if(key=="Script"&&xml.namespace()==fxNs)
			{
				checkAsFile(xml.toString());
				return;
			}
			if(isNaN(Number(key)))
			{
				excludeDic[key] = true;
			}
			for each(var attrib:XML in xml.attributes())
			{
				key = attrib.toString();
				var varList:Array = getVariables(key);
				for each(key in varList)
				{
					if(isNaN(Number(key)))
					{
						excludeDic[key] = true;
					}
				}
				
				key = attrib.localName();
				if(isNaN(Number(key)))
				{
					excludeDic[key] = true;
				}
			}
			
			for each(var item:XML in xml.children())
			{
				checkXmlFile(item);
			}
		}
		
		/**
		 * 获取变量关键字列表 
		 */		
		private function getVariables(codeText:String):Array
		{
			var list:Array = [];
			var word:String = "";
			var start:Boolean = false;
			var char:String = "";
			var lastChar:String = " ";
			while(codeText.length>0)
			{
				char = codeText.charAt(0);
				codeText = codeText.substring(1);
				if(start)
				{
					if(CodeUtil.isVariableChar(char))
					{
						word += char;
					}
					else
					{
						if(list.indexOf(word)==-1)
						{
							list.push(word);
						}
						word = "";
						start = false;
					}
				}
				else
				{
					if(CodeUtil.isVariableChar(char))
					{
						word = char;
						start = true;
					}
				}
				lastChar = char;
			}
			if(word)
			{
				if(list.indexOf(word)==-1)
				{
					list.push(word);
				}
			}
			return list;
		}
		
		/**
		 * 生成混淆后的源码
		 */		
		private function generateFiles(srcPaths:Array,keyWordPath:String):void
		{
			var keyBytes:ByteArray = FileUtil.openAsByteArray(keyWordPath);
			try
			{
				keyObject = keyBytes.readObject();
				for(var key:String in keyObject)
				{
					count++;
				}
			}
			catch(e:Error)
			{
				keyObject = {};
			}
			var fileList:Array = [];
			for each(var srcPath:String in srcPaths)
			{
				srcPath = new File(srcPath).nativePath;
				srcPath = FileUtil.escapeUrl(srcPath)+"/";
				var list:Array = FileUtil.search(srcPath,null,filterFunc2);
				for each(var file:File in list)
				{
					var ext:String = file.extension.toLowerCase();
					var targetPath:String = replaceSrc(file.nativePath,srcPath,targetSrc);
					if(ext=="as"||ext=="mxml")
					{
						var p:String = getPackage(file.nativePath);
						var name:String = FileUtil.getFileName(file.nativePath);
						if(keyList.indexOf(name)!=-1)
						{
							name = getKey(name);
						}
						if(packageList.indexOf(p)!=-1)
						{
							p = getKey(p);
						}
						p = p.split(".").join("/");
						targetPath = targetSrc+p+"/"+name+"."+file.extension;
						fileList.push(targetPath);
					}
					if(ext=="xml"||ext=="css")
					{
						fileList.push(targetPath);
					}
					FileUtil.copyTo(file.nativePath,targetPath,true);
				}
			}
			packageList.sort(sortOnLength);
			keyList.sort(sortOnLength);
			for each(var path:String in fileList)
			{
				var text:String = FileUtil.openAsString(path);
				for each(p in packageList)
				{
					text = replaceKeyWord(text,p,true);
				}
				for each(key in keyList)
				{
					text = replaceKeyWord(text,key);
				}
				FileUtil.save(path,text);
			}
			
			if(keyWordPath)
			{
				keyBytes = new ByteArray();
				keyBytes.writeObject(keyObject);
				FileUtil.save(keyWordPath,keyBytes);
			}
		}
		
		private function sortOnLength(strA:String,strB:String):int
		{
			return strB.length-strA.length;
		}
		/**
		 * 替换文本中出现的关键字
		 */		
		private function replaceKeyWord(text:String,key:String,isPackage:Boolean=false):String
		{
			var index:int = text.indexOf(key);
			var returnStr:String = "";
			while(index!=-1)
			{
				returnStr += text.substr(0,index);
				if(isFullWord(text,index,index+key.length,isPackage))
				{
					returnStr += getKey(key);
				}
				else 
				{
					returnStr += key;
				}
				text = text.substr(index+key.length);
				index = text.indexOf(key);
			}
			returnStr += text;
			return returnStr;
		}
		/**
		 * 检查这个字符串是不是一个完整词组
		 */		
		private function isFullWord(text:String,startIndex:int,
									endIndex:int,isPackage:Boolean=false):Boolean
		{
			startIndex--;
			var char:String = text.charAt(startIndex);
			if(char=="_"||char=="$"||(char>="0"&&char<="9")||(char>="a"&&char<="z")||(char>="A"&&char<="Z"))
			{
				return false;
			}
			else if(isPackage&&char==".")
			{
				return false;
			}
			char = text.charAt(endIndex);
			if(isPackage)
			{
				if(char==".")
				{
					var str:String = text.substring(0,startIndex);
					str = StringUtil.trimRight(str);
					if(str.substr(str.length-7,7)=="package")
						return false;
					str = text.substring(endIndex+1);
					str = ClassAnalyzer.getFirstWord(str);
					if(keyList.indexOf(str)!=-1)
						return true;
					var p:String = text.substring(startIndex+1,endIndex);
					p = getKey(p)+"."+str;
					if(FileUtil.exists(class2As(p))||FileUtil.exists(class2Mxml(p)))
						return true;
					var length:int = text.length;
					endIndex++;
					while(endIndex<length)
					{
						char = text.charAt(endIndex);
						if(char==".")
							return false;
						if(isNormalChar(char))
						{
							endIndex++;
							continue;
						}
						break;
					}
					return true;
				}
				else if(isNormalChar(char))
				{
					return false;
				}
			}
			else
			{
				if(isNormalChar(char))
				{
					return false;
				}
			}
			
			return true;
		}
		/**
		 * 检查作为变量的字符是否是合法
		 */		
		private function isNormalChar(char:String):Boolean
		{
			return Boolean(char=="_"||char=="$"||(char>="0"&&char<="9")||(char>="a"&&char<="z")||(char>="A"&&char<="Z"));
		}
		
		/**
		 * 类完全限定名转换为as路径
		 */		
		public function class2As(className:String):String
		{
			className = className.split("::").join(".");
			className = className.split(".").join("/");
			return targetSrc+className+".as";
		}
		/**
		 * 类完全限定名转换为mxml路径
		 */
		public function class2Mxml(className:String):String
		{
			className = className.split("::").join(".");
			className = className.split(".").join("/");
			return targetSrc+className+".mxml";
		}
		
		/**
		 * 混淆字典
		 */		
		private var keyObject:Object = {};
		/**
		 * 混淆关键字计数
		 */		
		private var count:int = 0;
		/**
		 * 生成混淆字符串
		 */		
		private function getKey(key:String):String
		{
			if(!keyObject[key])
			{
				count++;
				keyObject[key] = "_"+count;
			}
			return keyObject[key];
		}
		/**
		 * 把路径转换为包名
		 */		
		private function getPackage(path:String):String
		{
			path = FileUtil.getDirectory(path);
			var index:int = path.lastIndexOf("/src/");
			if(index==-1)
			{
				return path;
			}
			path = path.substring(index+5,path.length-1);
			return path.split("/").join(".");
		}
		/**
		 * 替换src路径
		 */		
		private function replaceSrc(path:String,source:String,dest:String):String
		{
			path = FileUtil.escapeUrl(path);
			return dest+path.substr(source.length);
		}
		/**
		 * 文件搜索回调函数
		 */		
		private function filterFunc2(file:File):Boolean
		{
			if(file.isDirectory)
			{
				if(file.name.charAt(0)!=".")
					return true;
			}
			else if(file.extension)
			{
				return true;
			}
			return false;
		}
	}
}
