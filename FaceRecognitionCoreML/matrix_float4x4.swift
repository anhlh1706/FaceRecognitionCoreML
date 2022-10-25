//
//  matrix_float4x4.swift
//  FaceRecognitionCoreML
//
//  Created by Bym on 22/10/2022.
//

import ARKit

extension matrix_float4x4 {
    
   func radiansToDegress(radians: Float32) -> Float32 {
       return radians * 180 / (Float32.pi)
   }
    
    var translation: SCNVector3 {
        SCNVector3Make(columns.3.x, columns.3.y, columns.3.z)
    }
    
   var eulerAngles: SCNVector3 {
       // Get quaternions
       // http://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/index.htm
       let qw = sqrt(1 + self.columns.0.x + self.columns.1.y + self.columns.2.z) / 2.0
       let qx = (self.columns.2.y - self.columns.1.z) / (qw * 4.0)
       let qy = (self.columns.0.z - self.columns.2.x) / (qw * 4.0)
       let qz = (self.columns.1.x - self.columns.0.y) / (qw * 4.0)
       
       // Deduce euler angles with some cosines
       // https://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles
       /// yaw (z-axis rotation)
       let siny = +2.0 * (qw * qz + qx * qy)
       let cosy = +1.0 - 2.0 * (qy * qy + qz * qz)
       let yaw = radiansToDegress(radians:atan2(siny, cosy))
       // pitch (y-axis rotation)
       let sinp = +2.0 * (qw * qy - qz * qx)
       var pitch: Float
       if abs(sinp) >= 1 {
           pitch = radiansToDegress(radians:copysign(Float.pi / 2, sinp))
       } else {
           pitch = radiansToDegress(radians:asin(sinp))
       }
       /// roll (x-axis rotation)
       let sinr = +2.0 * (qw * qx + qy * qz)
       let cosr = +1.0 - 2.0 * (qx * qx + qy * qy)
       let roll = radiansToDegress(radians:atan2(sinr, cosr))
       
       /// return array containing ypr values
       return SCNVector3(yaw, pitch, roll)
   }
}
