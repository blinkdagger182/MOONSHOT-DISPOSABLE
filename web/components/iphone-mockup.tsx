"use client";

import { cn } from "@/lib/utils";

interface IPhoneMockupProps {
  screenshot1: string;
  screenshot2: string;
  className?: string;
}

export function IPhoneMockup({
  screenshot1,
  screenshot2,
  className,
}: IPhoneMockupProps) {
  return (
    <div className={cn("relative w-full min-h-[500px] md:min-h-[600px]", className)}>
      {/* Perspective container */}
      <div className="perspective-container relative w-full h-full flex items-center justify-center">
        {/* Back phone (bottom-right) */}
        <div className="iphone-frame back-phone">
          <div className="iphone-bezel">
            <div className="dynamic-island" />
            <div className="iphone-screen">
              <img
                src={screenshot2}
                alt="App screenshot"
                className="screen-image"
              />
            </div>
          </div>
          {/* Side buttons */}
          <div className="side-button volume-up" />
          <div className="side-button volume-down" />
          <div className="side-button power" />
        </div>

        {/* Front phone (top-left) */}
        <div className="iphone-frame front-phone">
          <div className="iphone-bezel">
            <div className="dynamic-island" />
            <div className="iphone-screen">
              <img
                src={screenshot1}
                alt="App screenshot"
                className="screen-image"
              />
            </div>
          </div>
          {/* Side buttons */}
          <div className="side-button volume-up" />
          <div className="side-button volume-down" />
          <div className="side-button power" />
        </div>
      </div>

      <style jsx>{`
        .perspective-container {
          perspective: 1200px;
          transform-style: preserve-3d;
        }

        .iphone-frame {
          position: absolute;
          width: 280px;
          height: 570px;
          border-radius: 44px;
          background: linear-gradient(
            145deg,
            #1a1a1a 0%,
            #2d2d2d 50%,
            #1a1a1a 100%
          );
          padding: 12px;
          box-shadow: 
            0 25px 50px -12px rgba(0, 0, 0, 0.5),
            0 0 0 1px rgba(255, 255, 255, 0.1),
            inset 0 1px 0 rgba(255, 255, 255, 0.1);
          transform-style: preserve-3d;
        }

        .iphone-bezel {
          position: relative;
          width: 100%;
          height: 100%;
          background: #000;
          border-radius: 34px;
          overflow: hidden;
        }

        .dynamic-island {
          position: absolute;
          top: 12px;
          left: 50%;
          transform: translateX(-50%);
          width: 90px;
          height: 28px;
          background: #000;
          border-radius: 20px;
          z-index: 10;
        }

        .iphone-screen {
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          border-radius: 34px;
          overflow: hidden;
        }

        .screen-image {
          width: 100%;
          height: 100%;
          object-fit: cover;
          object-position: top;
        }

        /* Side buttons */
        .side-button {
          position: absolute;
          background: linear-gradient(90deg, #2d2d2d, #1a1a1a);
          border-radius: 2px;
        }

        .volume-up {
          left: -3px;
          top: 120px;
          width: 3px;
          height: 32px;
        }

        .volume-down {
          left: -3px;
          top: 165px;
          width: 3px;
          height: 32px;
        }

        .power {
          right: -3px;
          top: 140px;
          width: 3px;
          height: 64px;
        }

        /* Front phone positioning */
        .front-phone {
          z-index: 2;
          transform: 
            translateX(-60px) 
            translateY(-30px) 
            rotateY(12deg) 
            rotateX(2deg);
          animation: float-front 6s ease-in-out infinite;
        }

        /* Back phone positioning */
        .back-phone {
          z-index: 1;
          transform: 
            translateX(60px) 
            translateY(30px) 
            rotateY(12deg) 
            rotateX(2deg);
          animation: float-back 8s ease-in-out infinite;
          opacity: 0.95;
        }

        @keyframes float-front {
          0%, 100% {
            transform: 
              translateX(-60px) 
              translateY(-30px) 
              rotateY(12deg) 
              rotateX(2deg);
          }
          50% {
            transform: 
              translateX(-60px) 
              translateY(-40px) 
              rotateY(12deg) 
              rotateX(2deg);
          }
        }

        @keyframes float-back {
          0%, 100% {
            transform: 
              translateX(60px) 
              translateY(30px) 
              rotateY(12deg) 
              rotateX(2deg);
          }
          50% {
            transform: 
              translateX(60px) 
              translateY(20px) 
              rotateY(12deg) 
              rotateX(2deg);
          }
        }

        /* Responsive */
        @media (max-width: 768px) {
          .iphone-frame {
            width: 200px;
            height: 408px;
            border-radius: 32px;
            padding: 8px;
          }

          .iphone-bezel {
            border-radius: 26px;
          }

          .iphone-screen {
            border-radius: 26px;
          }

          .dynamic-island {
            width: 65px;
            height: 20px;
            top: 8px;
          }

          .front-phone {
            transform: 
              translateX(-40px) 
              translateY(-20px) 
              rotateY(10deg) 
              rotateX(2deg);
          }

          .back-phone {
            transform: 
              translateX(40px) 
              translateY(20px) 
              rotateY(10deg) 
              rotateX(2deg);
          }

          @keyframes float-front {
            0%, 100% {
              transform: 
                translateX(-40px) 
                translateY(-20px) 
                rotateY(10deg) 
                rotateX(2deg);
            }
            50% {
              transform: 
                translateX(-40px) 
                translateY(-28px) 
                rotateY(10deg) 
                rotateX(2deg);
            }
          }

          @keyframes float-back {
            0%, 100% {
              transform: 
                translateX(40px) 
                translateY(20px) 
                rotateY(10deg) 
                rotateX(2deg);
            }
            50% {
              transform: 
                translateX(40px) 
                translateY(12px) 
                rotateY(10deg) 
                rotateX(2deg);
            }
          }
        }

        @media (min-width: 1024px) {
          .iphone-frame {
            width: 320px;
            height: 652px;
            border-radius: 50px;
            padding: 14px;
          }

          .iphone-bezel {
            border-radius: 40px;
          }

          .iphone-screen {
            border-radius: 40px;
          }

          .dynamic-island {
            width: 100px;
            height: 32px;
            top: 14px;
          }

          .front-phone {
            transform: 
              translateX(-80px) 
              translateY(-40px) 
              rotateY(14deg) 
              rotateX(3deg);
          }

          .back-phone {
            transform: 
              translateX(80px) 
              translateY(40px) 
              rotateY(14deg) 
              rotateX(3deg);
          }

          @keyframes float-front {
            0%, 100% {
              transform: 
                translateX(-80px) 
                translateY(-40px) 
                rotateY(14deg) 
                rotateX(3deg);
            }
            50% {
              transform: 
                translateX(-80px) 
                translateY(-52px) 
                rotateY(14deg) 
                rotateX(3deg);
            }
          }

          @keyframes float-back {
            0%, 100% {
              transform: 
                translateX(80px) 
                translateY(40px) 
                rotateY(14deg) 
                rotateX(3deg);
            }
            50% {
              transform: 
                translateX(80px) 
                translateY(28px) 
                rotateY(14deg) 
                rotateX(3deg);
            }
          }
        }
      `}</style>
    </div>
  );
}
