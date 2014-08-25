package com.domlib.encrypt
{
	import com.domlib.utils.ClassUtil;
	import com.domlib.utils.CodeFilter;
	import com.domlib.utils.FileUtil;
	import com.domlib.utils.StringUtil;
	
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	import flash.utils.Dictionary;
	
	
	/**
	 * AS3源码分析工具
	 * @author dom
	 */
	public class ClassAnalyzer extends EventDispatcher
	{
		public function ClassAnalyzer()
		{
			super();
		}
		/**
		 * 工程源代码路径
		 */
		public var srcPath:String = "";

		/**
		 * 开始混淆
		 */
		public function startAnalyze(srcPath:String):void
		{
			if(!srcPath)
				return;
			this.srcPath = FileUtil.escapePath(srcPath);
			analyzeFiles();
		}
		
		/**
		 * as路径转换为类名
		 */		
		public function as2Class(path:String):String
		{
			path = FileUtil.escapeUrl(path);
			var className:String;
			className = path.substring(srcPath.length,path.length-3);
			className = className.split("/").join(".");
			return className;
		}
		/**
		 * 类完全限定名转换为as路径
		 */		
		public function class2As(className:String):String
		{
			className = className.split("::").join(".");
			className = className.split(".").join("/");
			return srcPath+className+".as";
		}
		/**
		 * mxml路径转换为类名
		 */		
		public function mxml2Class(path:String):String
		{
			path = FileUtil.escapeUrl(path);
			var className:String;
			className = path.substring(srcPath.length,path.length-5);
			className = className.split("/").join(".");
			return className;
		}
		/**
		 * 类完全限定名转换为mxml路径
		 */		
		public function class2Mxml(className:String):String
		{
			className = className.split("::").join(".");
			className = className.split(".").join("/");
			return srcPath+className+".mxml";
		}
		
		/**
		 * as文件列表
		 */		
		private var classInfoList:Vector.<ClassInfo> = new Vector.<ClassInfo>();
		
		private var classInfoDic:Dictionary = new Dictionary();
		/**
		 * 获取包名列表
		 */		
		public function get getPackageList():Array
		{
			var list:Array = [];
			for each(var info:ClassInfo in classInfoList)
			{
				if(info.packageName&&list.indexOf(info.packageName)==-1)
					list.push(info.packageName);
			}
			return list;
		}
		/**
		 * 获取关键字列表
		 */		
		public function get keyList():Array
		{
			var list:Array = [];
			var key:String;
			for each(var info:ClassInfo in classInfoList)
			{
				key = info.className;
				if(key&&list.indexOf(key)==-1)
					list.push(key);
				for each(key in info.privateVars)
				{
					if(key&&list.indexOf(key)==-1)
						list.push(key);
				}
				for each(key in info.privateFuncs)
				{
					if(key&&list.indexOf(key)==-1)
						list.push(key);
				}
				for each(key in info.publicVars)
				{
					if(key&&list.indexOf(key)==-1)
						list.push(key);
				}
				for each(key in info.publicFuncs)
				{
					if(key&&list.indexOf(key)==-1)
						list.push(key);
				}
			}
			return list;
		}
		/**
		 * 分析文件
		 */		
		private function analyzeFiles():void
		{
			classInfoList = new Vector.<ClassInfo>();
			classInfoDic = new Dictionary();
			FileUtil.search(srcPath,null,filterFunc);
		}
		
		private function filterFunc(file:File):Boolean
		{
			if(file.isDirectory)
			{
				if(file.name.charAt(0)!=".")
					return true;
			}
			else if(file.extension)
			{
				var ext:String = file.extension.toLowerCase();
				if(ext=="as")
					analyzeAS(FileUtil.escapeUrl(file.nativePath));
				else if(ext=="mxml")
					analyzeMXML(FileUtil.escapeUrl(file.nativePath));
			}
			return false;
		}
		
		/**
		 * 解析一个mxml文件
		 */		
		private function analyzeMXML(path:String):void
		{
			if(classInfoDic[path])
				return;
			var info:ClassInfo = new ClassInfo();
			classInfoDic[path] = info;
			info.type = "mxml";
			info.filePath = path;
			var className:String = mxml2Class(path);
			info.className = ClassUtil.getID(className);
			info.packageName = ClassUtil.getPackage(className);
			var mxmlText:String = FileUtil.openAsString(path);
			var xml:XML;
			try
			{
				xml = new XML(mxmlText);
			}
			catch(e:Error)
			{
			}
			if(xml)
			{
				var ns:Namespace = xml.namespace();
				if(!isDefaultNs(ns))
				{
					var superClass:String = ns.uri;
					info.superClass = superClass.substring(0,superClass.length-1)+xml.localName();
				}
				
				if(xml.hasOwnProperty("@implements"))
				{
					var implStr:String = xml["@implements"];
					var implStrs:Array = implStr.split(",");
					for each(var impl:String in implStrs)
					{
						impl = StringUtil.trim(impl);
						if(impl)
							info.implementsList.push(impl);
					}
				}
				
				var fx:Namespace = new Namespace("fx","http://ns.adobe.com/mxml/2009");
				var script:XML = xml.fx::Script[0];
				if(script)
				{
					var asText:String = script.toString();
					var index:int = asText.lastIndexOf("import ");
					if(index!=-1)
					{
						var tailStr:String = asText.substr(index);
						var i:int = tailStr.indexOf(";");
						var j:int = tailStr.indexOf("\n");
						if(j!=-1&&i!=-1&&j<i)
							i = j;
						var impStr:String = asText.substr(0,index+i+1);
						getImports(impStr,info);
						asText = asText.substr(index+i+1);
					}
					getVarsAndFuncs(asText,info);
				}
			}
			classInfoList.push(info);
		}
		
		/**
		 * 使用框架配置文件的默认命名空间 
		 */		
		private const DEFAULT_NS:Array = 
			[new Namespace("s","library://ns.adobe.com/flex/spark"),
				new Namespace("mx","library://ns.adobe.com/flex/mx"),
				new Namespace("fx","http://ns.adobe.com/mxml/2009")];
		
		/**
		 * 指定的命名空间是否是默认命名空间
		 */		
		private function isDefaultNs(ns:Namespace):Boolean
		{
			for each(var dns:Namespace in DEFAULT_NS)
			{
				if(ns==dns)
					return true;
			}
			return false;
		}
		
		private var codeFilter:CodeFilter = new CodeFilter();
		/**
		 * 解析一个as文件
		 */		
		private function analyzeAS(path:String):void
		{
			if(classInfoDic[path])
				return;
			var info:ClassInfo = new ClassInfo();
			classInfoDic[path] = info;
			info.type = "as";
			info.filePath = path;
			var className:String = as2Class(path);
			info.className = ClassUtil.getID(className);
			info.packageName = ClassUtil.getPackage(className);
			var asText:String = FileUtil.openAsString(path);
			asText = codeFilter.removeComment(asText);
			
			var isInterface:Boolean = false;
			var index:int = asText.indexOf(" interface ");
			if(index==-1)
			{
				index = asText.indexOf(" class ");
			}
			else
			{
				isInterface = true;
			}
			var importStr:String = asText.substr(0,index);
			getImports(importStr,info);
			asText = asText.substr(index);
			if(!isInterface)
			{
				index = asText.indexOf("extends ");
				if(index !=-1)
				{
					asText = StringUtil.trimLeft(asText.substr(index+8));
					var superClass:String = getFirstWord(asText);
					info.superClass = getFullClassName(superClass,info);
				}
			}
			
			index = asText.indexOf("{");
			var implStr:String = asText.substr(0,index);
			asText = StringUtil.trimLeft(asText.substr(index+1));
			if(isInterface)
			{
				index = implStr.indexOf("extends ");
			}
			else
			{
				index = implStr.indexOf("implements ");
				
			}
			if(index!=-1)
			{
				implStr = StringUtil.trimLeft(implStr.substr(index+11));
				var implStrs:Array = implStr.split(",");
				var length:int = implStrs.length;
				for each(var impl:String in implStrs)
				{
					impl = getFullClassName(StringUtil.trim(impl),info);
					if(impl)
						info.implementsList.push(impl);
				}
			}
			getVarsAndFuncs(asText,info);
			classInfoList.push(info);
		}
		/**
		 * 获取导入包列表
		 */		
		private function getImports(importStr:String,info:ClassInfo):void
		{
			var importStrs:Array = importStr.split("\n");
			
			var length:int = importStrs.length;
			for(var index:int=0;index<length;index++)
			{
				var impStr:String = importStrs[index];
				var impIndex:int = impStr.indexOf("import ");
				if(impIndex!=-1)
				{
					impStr = StringUtil.trim(impStr.substr(impIndex+7));
					while(impStr.length>0)
					{
						if(impStr.charAt(impStr.length-1)==";")
							impStr = impStr.substr(0,impStr.length-1);
						else
							break;
					}
					info.importList.push(impStr);
				}
			}
		}
		/**
		 * 获取变量和函数名列表
		 */		
		private function getVarsAndFuncs(asText:String,info:ClassInfo):void
		{
			var closed:Boolean = true;
			var index:int;
			var indent:int = 2;
			while(asText.length>0)
			{
				var contentText:String = "";
				index = asText.indexOf("{");
				var i:int = asText.indexOf("}");
				if(index!=-1&&(i==-1||i>index))
				{
					if(indent==2)
						contentText = asText.substr(0,index);
					asText = asText.substr(index+1);
					indent++;
				}
				else if(i!=-1)
				{
					if(indent==2)
						contentText = asText.substr(0,i);
					asText = asText.substr(i+1);
					indent--;
				}
				else
				{
					contentText = asText;
					asText = "";
				}
				if(contentText)
				{
					while(contentText.length>0)
					{
						index = contentText.indexOf("function ");
						i = contentText.indexOf("var ");
						if(index!=-1&&(i==-1||i>index))
						{
							var preStr:String = contentText.substr(0,index+9);
							contentText = contentText.substr(index+9);
							if(preStr.indexOf("override ")!=-1)
								continue;
							var key:String = getFirstWord(contentText);
							if(key=="set"||key=="get")
							{
								var isGet:Boolean = (key=="get");
								index = contentText.indexOf(key);
								key = getFirstWord(contentText.substr(index+3));
								if(isPrivate(preStr))
								{
									if(info.privateVars.indexOf(key)==-1)
										info.privateVars.push(key);
								}
								else
								{
									if(info.publicVars.indexOf(key)==-1)
										info.publicVars.push(key);
								}
								if(isGet)
								{
									index = contentText.indexOf(")");
									contentText = contentText.substr(index+1);
								}
								index = contentText.indexOf(":");
								contentText = contentText.substr(index+1);
								var type:String = getFirstWord(contentText);
								info.typeDic[key] = getFullClassName(type,info);
							}
							else if(key)
							{
								if(isPrivate(preStr))
									info.privateFuncs.push(key);
								else
									info.publicFuncs.push(key);
								index = contentText.indexOf(")");
								contentText = contentText.substr(index+1);
								index = contentText.indexOf(":");
								contentText = contentText.substr(index+1);
								type = getFirstWord(contentText);
								info.typeDic[key] = getFullClassName(type,info);
							}
						}
						else if(i!=-1)
						{
							index = contentText.indexOf("var ");
							preStr = contentText.substr(0,index+4);
							contentText = contentText.substr(index+4);
							key = getFirstWord(contentText);
							if(key)
							{
								if(isPrivate(preStr))
									info.privateVars.push(key);
								else
									info.publicVars.push(key);
								index = contentText.indexOf(":");
								contentText = contentText.substr(index+1);
								type = getFirstWord(contentText);
								info.typeDic[key] = getFullClassName(type,info);
							}
						}
						else
						{
							break;
						}
					}
				}
			}
		}
		
		/**
		 * 是否含有private
		 */		
		private function isPrivate(str:String):Boolean
		{
			var i:int = str.lastIndexOf("private");
			var j:int = str.lastIndexOf("public");
			var k:int = str.lastIndexOf("protected");
			if(i>j&&i>k)
				return true;
			return false;
		}
		/**
		 * 获取完整的类名
		 */		
		private function getFullClassName(className:String,info:ClassInfo):String
		{
			if(className.indexOf(".")!=-1)
				return className;
			var found:Boolean = false;
			for each(var classStr:String in info.importList)
			{
				if(ClassUtil.getID(classStr)==className)
				{
					found = true;
					className = classStr;
					break;
				}
			}
			if(!found&&info.packageName)
			{
				var full:String = info.packageName+"."+className;
				if(FileUtil.exists(class2As(full))||FileUtil.exists(class2Mxml(full)))
					className = full;
			}
			return className;
		}
		
		/**
		 * 获取第一个词组字符串
		 */		
		public static function getFirstWord(str:String):String
		{
			str = StringUtil.trimLeft(str);
			var length:int = str.length;
			var index:int = 0;
			while(index<length)
			{
				var char:String = str.charAt(index);
				if(char!="_"&&char!="$"&&(char<"0"||char>"9")&&(char<"a"||char>"z")&&(char<"A"||char>"Z"))
				{
					break;
				}
				index++;
			}
			return str.substr(0,index);
		}
	}
}