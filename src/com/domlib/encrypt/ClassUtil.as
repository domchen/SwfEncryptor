package com.domlib.encrypt
{
	
	/**
	 * 类名工具
	 * @author DOM
	 */
	public class ClassUtil
	{
		/**
		 * 获取类的短名
		 */		
		public static function getID(className:String):String
		{
			if(!className)
				return className;
			className = className.split("::").join(".");
			var index:int = className.lastIndexOf(".");
			if(index==-1)
				return className;
			return className.substring(index+1);
		}
		/**
		 * 获取包名
		 */
		public static function getPackage(className:String):String
		{
			if(!className)
				return "";
			className = className.split("::").join(".");
			var index:int = className.lastIndexOf(".");
			if(index==-1)
				return "";
			return className.substring(0,index);
		}
		/**
		 * 根据包名和类短名获取完整类名
		 */		
		public static function getClassName(packageName:String,id:String):String
		{
			if(!packageName)
				return id;
			return packageName+"."+id;
		}
	}
}