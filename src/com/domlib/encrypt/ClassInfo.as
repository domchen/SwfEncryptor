package com.domlib.encrypt
{
	import flash.utils.Dictionary;
	
	/**
	 * 类属性
	 * @author DOM
	 */
	public class ClassInfo
	{
		public function ClassInfo()
		{
		}
		/**
		 * 类型：as，mxml
		 */		
		public var type:String = "as";
		/**
		 * 文件路径
		 */		
		public var filePath:String = "";
		/**
		 * 类名
		 */		
		public var className:String = "";
		/**
		 * 包名
		 */		
		public var packageName:String = "";
		/**
		 * 父级类名
		 */		
		public var superClass:String = "";
		/**
		 * 导入的包列表
		 */		
		public var importList:Vector.<String> = new Vector.<String>();
		/**
		 * 实现的接口列表
		 */		
		public var implementsList:Vector.<String> = new Vector.<String>();
		/**
		 * 私有变量名列表
		 */		
		public var privateVars:Vector.<String> = new Vector.<String>();
		/**
		 * 公开变量名列表
		 */		
		public var publicVars:Vector.<String> = new Vector.<String>();
		/**
		 * 私有函数名列表
		 */		
		public var privateFuncs:Vector.<String> = new Vector.<String>();
		/**
		 * 公开函数名列表
		 */		
		public var publicFuncs:Vector.<String> = new Vector.<String>();
		/**
		 * 变量和函数名对应的值类型
		 */		
		public var typeDic:Dictionary = new Dictionary();
		
	}
}