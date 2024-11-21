import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import vercelStatic from "@astrojs/vercel/static";

// https://astro.build/config
export default defineConfig({
  output: "static",
  adapter: vercelStatic(),
  integrations: [
    starlight({
      favicon: "favicon.ico",
      title: "suchcodewow",
      customCss: ["./src/styles.css"],
      components: {
        Sidebar: "./src/components/Sidebar.astro",
      },
      logo: {
        src: "/src/img/wow.png",
      },
      tableOfContents: {
        minHeadingLevel: 2,
        maxHeadingLevel: 3,
      },
      social: {
        github: "https://github.com/suchcodewow/scwastro",
      },
      sidebar: [
        {
          label: "Pepper",
          autogenerate: {
            directory: "pepper",
          },
        },
        {
          label: "Scripts",
          autogenerate: {
            directory: "scripts",
          },
        },
        {
          label: "Accelerators",
          autogenerate: {
            directory: "accelerators",
          },
        },
        {
          label: "Harness",
          autogenerate: {
            directory: "harness",
          },
        },
        {
          label: "Full Stack Front-to-Back",
          autogenerate: {
            directory: "fronttoback",
          },
        },
      ],
    }),
  ],
});
