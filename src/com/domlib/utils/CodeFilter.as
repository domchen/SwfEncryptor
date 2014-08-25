package com.domlib.utils
{
	/**
	 * 过滤代码中的所有常量和注释内容的工具类
	 * @author dom
	 */
	public class CodeFilter
	{
		/**
		 * 构造函数
		 */		
		public function CodeFilter()
		{
		}
			
		/**
		 * 是否为占位符
		 */	
		public static function isNBSP(str:String):Boolean
		{
			if(!str||str.length<3)
				return false;
			return str.charAt(0)=="\v"&&str.charAt(str.length-1)=="\v";
		}
		/**
		 * 获取文本末尾的占位符。若最后一个字符不是占位符。返回""
		 */		
		public static function getLastNBSP(str:String):String
		{
			if(!str||str.length<3||str.charAt(str.length-1)!="\v")
				return "";
			str = str.substring(0,str.length-1);
			var index:int = str.lastIndexOf("\v");
			if(index==-1)
				return "";
			var char:String = str.substring(index+1);
			if(isNaN(parseInt(char)))
				return "";
			return str.substring(index)+"\v";
		}
		/**
		 * 获取文本末尾的占位符。若最后一个字符不是占位符。返回""
		 */		
		public static function getFirstNBSP(str:String):String
		{
			if(!str||str.length<3||str.charAt(0)!="\v")
				return "";
			str = str.substring(1);
			var index:int = str.indexOf("\v");
			if(index==-1)
				return "";
			var char:String = str.substring(0,index);
			if(isNaN(parseInt(char)))
				return "";
			return "\v"+str.substring(0,index+1);
		}
		
		private function getCommentIndex(str:String):int
		{
			return parseInt(str.substring(1,str.length-1));
		}
		
		private var nbsp:String = null;
		/**
		 * 获取占位符
		 */		
		private function getNBSP():String
		{
			if(nbsp!==null)
				return nbsp;
			return "\v"+commentLines.length+"\v";
		}
		/**
		 * 注释行
		 */		
		private var commentLines:Array = [];
		/**
		 * 移除代码注释和字符串常量
		 */		
		public function removeComment(codeText:String,nbsp:String=null):String
		{
			this.nbsp = nbsp;
			var trimText:String = "";
			codeText = codeText.split("\\\\").join("\v-0\v");
			codeText = codeText.split("\\\"").join("\v-1\v");
			codeText = codeText.split("\\\'").join("\v-2\v");
			commentLines = [];
			while(codeText.length>0)
			{
				var quoteIndex:int = codeText.indexOf("\"");
				if(quoteIndex==-1)
					quoteIndex = int.MAX_VALUE;
				var squoteIndex:int = codeText.indexOf("'");
				if(squoteIndex==-1)
					squoteIndex = int.MAX_VALUE;
				var commentIndex:int = codeText.indexOf("/*");
				if(commentIndex==-1)
					commentIndex = int.MAX_VALUE;
				var lineCommonentIndex:int = codeText.indexOf("//");
				if(lineCommonentIndex==-1)
					lineCommonentIndex = int.MAX_VALUE;
				var index:int = Math.min(quoteIndex,squoteIndex,commentIndex,lineCommonentIndex);
				if(index==int.MAX_VALUE)
				{
					trimText += codeText;
					break;
				}
				trimText += codeText.substring(0,index)+getNBSP();
				codeText = codeText.substring(index);
				switch(index)
				{
					case quoteIndex:
						codeText = codeText.substring(1);
						index = codeText.indexOf("\"");
						if(index==-1)
							index = codeText.length-1;
						commentLines.push("\""+codeText.substring(0,index+1));
						codeText = codeText.substring(index+1);
						break;
					case squoteIndex:
						codeText = codeText.substring(1);
						index = codeText.indexOf("'");
						if(index==-1)
							index=codeText.length-1;
						commentLines.push("'"+codeText.substring(0,index+1));
						codeText = codeText.substring(index+1);
						break;
					case commentIndex:
						index = codeText.indexOf("*/");
						if(index==-1)
							index=codeText.length-1;
						commentLines.push(codeText.substring(0,index+2));
						codeText = codeText.substring(index+2);
						break;
					case lineCommonentIndex:
						index = codeText.indexOf("\n");
						if(index==-1)
							index=codeText.length-1;
						commentLines.push(codeText.substring(0,index));
						codeText = codeText.substring(index);
						break;
				}
			}
			codeText = trimText.split("\v-0\v").join("\\\\");
			codeText = codeText.split("\v-1\v").join("\\\"");
			codeText = codeText.split("\v-2\v").join("\\\'");
			var length:int = commentLines.length;
			for(var i:int=0;i<length;i++)
			{
				var constStr:String = commentLines[i];
				constStr = constStr.split("\v-0\v").join("\\\\");
				constStr = constStr.split("\v-1\v").join("\\\"");
				constStr = constStr.split("\v-2\v").join("\\\'");
				commentLines[i] = constStr;
			}
			return codeText;
		}
		/**
		 * 更新缩进后，同步更新对应包含的注释行。
		 * @param preStr 发生改变字符串之前的字符串内容
		 * @param changeStr 发生改变的字符串
		 * @param numIndent 要添加或减少的缩进。整数表示添加，负数减少。
		 */			
		public function updateCommentIndent(changeStr:String,numIndent:int=1):void
		{
			if(!changeStr)
				return;
			while(changeStr.length>0)
			{
				var index:int = changeStr.indexOf("\v");
				if(index==-1)
				{
					break;
				}
				changeStr = changeStr.substring(index);
				var str:String = getFirstNBSP(changeStr)
				if(str)
				{
					changeStr = changeStr.substring(str.length);
					index = getCommentIndex(str);
					if(numIndent>0)
					{
						commentLines[index] = CodeUtil.addIndent(commentLines[index],numIndent,true);
					}
					else
					{
						commentLines[index] = CodeUtil.removeIndent(commentLines[index],-numIndent);
					}
				}
				else
				{
					changeStr = changeStr.substring(1);
				}
			}
		}
		/**
		 * 回复注释行
		 */		
		public function recoveryComment(codeText:String):String
		{
			if(!codeText)
				return codeText;
			var constArray:Array = this.commentLines.concat();
			var tsText:String = "";
			while(codeText.length>0)
			{
				var index:int = codeText.indexOf("\v");
				if(index==-1)
				{
					tsText += codeText;
					break;
				}
				tsText += codeText.substring(0,index);
				codeText = codeText.substring(index);
				var str:String = getFirstNBSP(codeText);
				if(str)
				{
					index = getCommentIndex(str);
					tsText += constArray[index];
					codeText = codeText.substring(str.length);
				}
				else
				{
					tsText += "\v";
					codeText = codeText.substring(1)
				}
			}
			return tsText;
		}
	}
}